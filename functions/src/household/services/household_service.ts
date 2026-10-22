import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {MembershipService} from "../../membership/services/membership_service";
import {
  throwFailedPrecondition,
  throwInvalidArgument,
  throwNotFound,
  throwPermissionDenied,
  throwResourceExhausted,
} from "../../utils/errors";
import {
  generateInviteCode,
  isValidInviteCode,
  normalizeInviteCode,
} from "./invite_code";

/** Invitation lifetime (PLAN_05 D3). */
export const INVITATION_TTL_DAYS = 7;
/**
 * Hard ceiling on members per household, applied even when a plan's
 * `memberLimit` is null (unlimited) or misconfigured, to prevent abuse.
 */
export const MAX_HOUSEHOLD_MEMBERS = 20;
/** Wrong invite codes allowed per window before the user is locked out. */
export const MAX_FAILED_INVITE_ATTEMPTS = 10;
export const INVITE_ATTEMPT_WINDOW_MS = 60 * 60 * 1000;
/** Retries when a freshly generated code collides with an existing doc. */
const CODE_GENERATION_ATTEMPTS = 5;

const INVALID_CODE_MESSAGE = "Mã lời mời không hợp lệ hoặc không tồn tại.";

export interface HouseholdMemberInfo {
  id: string;
  fullName: string;
  avatarUrl: string | null;
  role: "owner" | "member";
  isCurrentUser: boolean;
}

export interface HouseholdInvitationResult {
  invitationId: string;
  code: string;
  householdId: string;
  householdName: string;
  expiresAt: string;
}

export interface HouseholdInvitationPreview {
  code: string;
  householdId: string;
  householdName: string;
  ownerName: string;
  memberCount: number;
  /** Seats allowed by the owner's plan (owner included). */
  memberLimit: number;
  alreadyMember: boolean;
  expiresAt: string;
}

/** Member cap of a household, taken from its owner's plan (PLAN_05 D2). */
interface HouseholdMemberLimit {
  limit: number;
  planName: string;
}

/** Outcome of validating an invitation document. */
type InvitationCheck =
  | {ok: true; data: DocumentData; expiresAt: Date}
  | {ok: false; message: string; markExpired: boolean};

/**
 * Validates an invitation snapshot without throwing, so callers can count a
 * failed attempt outside the transaction before surfacing the error.
 * @param {DocumentData | undefined} data Invitation data, if the doc exists.
 * @return {InvitationCheck} Validation outcome.
 */
function checkInvitation(data: DocumentData | undefined): InvitationCheck {
  if (!data) {
    return {ok: false, message: INVALID_CODE_MESSAGE, markExpired: false};
  }
  if (data.status !== "active") {
    return {
      ok: false,
      message: data.status === "revoked" ?
        "Mã lời mời này đã bị chủ gia đình thu hồi." :
        "Mã lời mời này không còn hiệu lực.",
      markExpired: false,
    };
  }
  const expiresAt = (data.expiresAt as Timestamp).toDate();
  if (expiresAt.getTime() <= Date.now()) {
    return {ok: false, message: "Mã lời mời này đã hết hạn.", markExpired: true};
  }
  return {ok: true, data, expiresAt};
}

export class HouseholdService {
  /**
   * Generates a new invitation code and revokes the previous active one, so
   * each household has at most one valid code. Owner only (BR-03).
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Target household.
   * @return {Promise<HouseholdInvitationResult>} The new invitation.
   */
  static async createInvitation(
    callerUid: string,
    householdId: string
  ): Promise<HouseholdInvitationResult> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const invitations = db.collection(Collections.HOUSEHOLD_INVITATIONS);
    const expiresAtDate = new Date(
      Date.now() + INVITATION_TTL_DAYS * 24 * 60 * 60 * 1000
    );

    const result = await db.runTransaction(async (tx) => {
      // Reads first: Firestore transactions reject reads after writes.
      const householdSnap = await tx.get(householdRef);
      if (!householdSnap.exists) {
        throwNotFound("Không tìm thấy thông tin gia đình.");
      }
      const householdData = householdSnap.data()!;
      if (householdData.ownerId !== callerUid) {
        throwPermissionDenied("Chỉ chủ gia đình mới có quyền tạo mã lời mời.");
      }

      const activeSnap = await tx.get(
        invitations
          .where("householdId", "==", householdId)
          .where("status", "==", "active")
      );

      // The code is the document id, so uniqueness is checked by reading it.
      let codeRef: DocumentReference | null = null;
      for (let i = 0; i < CODE_GENERATION_ATTEMPTS && !codeRef; i++) {
        const candidate = invitations.doc(generateInviteCode());
        if (!(await tx.get(candidate)).exists) {
          codeRef = candidate;
        }
      }
      if (!codeRef) {
        throwFailedPrecondition("Không thể tạo mã lời mời, vui lòng thử lại.");
      }

      const serverTimestamp = FieldValue.serverTimestamp();
      for (const doc of activeSnap.docs) {
        tx.update(doc.ref, {status: "revoked", updatedAt: serverTimestamp});
      }

      const householdName = householdData.name || "Gia đình FOORA";
      tx.create(codeRef, {
        code: codeRef.id,
        householdId,
        householdName,
        createdBy: callerUid,
        status: "active",
        useCount: 0,
        expiresAt: Timestamp.fromDate(expiresAtDate),
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });

      return {code: codeRef.id, householdName};
    });

    logger.info(
      `[HouseholdService] User ${callerUid} created invitation ` +
      `${result.code} for household ${householdId}`
    );

    return {
      invitationId: result.code,
      code: result.code,
      householdId,
      householdName: result.householdName,
      expiresAt: expiresAtDate.toISOString(),
    };
  }

  /**
   * Returns invitation details so the user can confirm before joining.
   * Counts towards the wrong-code limit to prevent code enumeration.
   * @param {string} callerUid Authenticated user id.
   * @param {string} rawCode Code as typed by the user.
   * @return {Promise<HouseholdInvitationPreview>} Preview data.
   */
  static async getInvitationInfo(
    callerUid: string,
    rawCode: string
  ): Promise<HouseholdInvitationPreview> {
    await this.assertNotLockedOut(callerUid);
    const code = await this.requireValidCodeFormat(callerUid, rawCode);

    const invRef = db.collection(Collections.HOUSEHOLD_INVITATIONS).doc(code);
    const invSnap = await invRef.get();
    const check = checkInvitation(invSnap.data());
    if (!check.ok) {
      if (check.markExpired) {
        await invRef.update({
          status: "expired",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await this.recordFailedAttempt(callerUid);
      throwNotFound(check.message);
    }

    const householdSnap = await db
      .collection(Collections.HOUSEHOLDS)
      .doc(check.data.householdId)
      .get();
    if (!householdSnap.exists) {
      throwNotFound("Gia đình liên kết với lời mời này không còn tồn tại.");
    }

    const householdData = householdSnap.data()!;
    const members: string[] = householdData.members || [];
    const {limit} = await this.getMemberLimit(householdData.ownerId);

    let ownerName = "Chủ gia đình";
    if (householdData.ownerId) {
      const ownerSnap = await db
        .collection(Collections.USERS)
        .doc(householdData.ownerId)
        .get();
      ownerName = ownerSnap.data()?.fullName || ownerName;
    }

    return {
      code,
      householdId: check.data.householdId,
      householdName: householdData.name || check.data.householdName,
      ownerName,
      memberCount: members.length,
      memberLimit: limit,
      alreadyMember: members.includes(callerUid),
      expiresAt: check.expiresAt.toISOString(),
    };
  }

  /**
   * Joins a household with an invitation code and makes it the active one.
   * Re-joining a household the user already belongs to only switches to it.
   * @param {string} callerUid Authenticated user id.
   * @param {string} rawCode Code as typed by the user.
   * @return {Promise<object>} Joined household id and name.
   */
  static async joinHousehold(
    callerUid: string,
    rawCode: string
  ): Promise<{householdId: string; householdName: string}> {
    await this.assertNotLockedOut(callerUid);
    const code = await this.requireValidCodeFormat(callerUid, rawCode);

    const invRef = db.collection(Collections.HOUSEHOLD_INVITATIONS).doc(code);
    const userRef = db.collection(Collections.USERS).doc(callerUid);

    // The invitation is re-read inside the transaction so a concurrent revoke
    // cannot let a user in after the owner disabled the code.
    const outcome = await db.runTransaction(async (tx) => {
      const invSnap = await tx.get(invRef);
      const check = checkInvitation(invSnap.data());
      if (!check.ok) {
        if (check.markExpired) {
          tx.update(invRef, {
            status: "expired",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return {joined: false as const, full: false as const, message: check.message};
      }

      const householdId: string = check.data.householdId;
      const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
      const [householdSnap, userSnap] = await Promise.all([
        tx.get(householdRef),
        tx.get(userRef),
      ]);
      if (!householdSnap.exists) {
        throwNotFound("Gia đình không tồn tại.");
      }

      const householdData = householdSnap.data()!;
      const householdName: string = householdData.name || "Gia đình FOORA";
      const members: string[] = householdData.members || [];
      const serverTimestamp = FieldValue.serverTimestamp();

      if (members.includes(callerUid)) {
        tx.update(userRef, {
          activeHouseholdId: householdId,
          updatedAt: serverTimestamp,
        });
        return {joined: true as const, householdId, householdName};
      }

      const {limit, planName} = await this.getMemberLimit(householdData.ownerId);
      if (members.length >= limit) {
        // Existing members are never removed when a plan is downgraded;
        // only new joins are blocked.
        return {
          joined: false as const,
          full: true as const,
          ownerId: householdData.ownerId as string,
          householdId,
          householdName,
          memberName: (userSnap.data()?.fullName as string) || "Một người",
          message:
            `Gia đình này đã đủ ${limit} thành viên theo gói ${planName} ` +
            "của chủ gia đình. Hãy nhờ chủ gia đình nâng cấp Premium để " +
            "mời thêm thành viên.",
        };
      }

      tx.update(householdRef, {
        members: FieldValue.arrayUnion(callerUid),
        updatedAt: serverTimestamp,
      });
      tx.update(invRef, {
        useCount: FieldValue.increment(1),
        updatedAt: serverTimestamp,
      });
      tx.update(userRef, {
        activeHouseholdId: householdId,
        updatedAt: serverTimestamp,
      });

      if (householdData.ownerId) {
        const memberName = userSnap.data()?.fullName || "Một thành viên mới";
        this.createSystemNotification(tx, householdData.ownerId, householdId, {
          title: "Thành viên mới",
          message: `${memberName} đã tham gia "${householdName}".`,
        });
      }

      return {joined: true as const, householdId, householdName};
    });

    if (!outcome.joined && outcome.full) {
      await this.notifyOwnerHouseholdFull(
        outcome.ownerId,
        outcome.householdId,
        outcome.householdName,
        callerUid,
        outcome.memberName
      );
      throwFailedPrecondition(outcome.message);
    }
    if (!outcome.joined) {
      await this.recordFailedAttempt(callerUid);
      throwNotFound(outcome.message);
    }

    await this.clearFailedAttempts(callerUid);
    logger.info(
      `[HouseholdService] User ${callerUid} joined household ` +
      `${outcome.householdId} (${outcome.householdName})`
    );

    return {householdId: outcome.householdId, householdName: outcome.householdName};
  }

  /**
   * Revokes the household's invitation. Owner only (BR-03).
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Household owning the invitation.
   * @param {string} invitationId Invitation id (the code).
   * @return {Promise<void>}
   */
  static async revokeInvitation(
    callerUid: string,
    householdId: string,
    invitationId: string
  ): Promise<void> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const invRef = db.collection(Collections.HOUSEHOLD_INVITATIONS).doc(invitationId);

    await db.runTransaction(async (tx) => {
      const [householdSnap, invSnap] = await Promise.all([
        tx.get(householdRef),
        tx.get(invRef),
      ]);
      if (!householdSnap.exists) {
        throwNotFound("Không tìm thấy thông tin gia đình.");
      }
      if (householdSnap.data()?.ownerId !== callerUid) {
        throwPermissionDenied("Chỉ chủ gia đình mới có quyền thu hồi lời mời.");
      }
      // Never let an owner touch another household's invitation.
      if (!invSnap.exists || invSnap.data()?.householdId !== householdId) {
        throwNotFound("Không tìm thấy lời mời.");
      }
      if (invSnap.data()?.status !== "active") {
        return;
      }

      tx.update(invRef, {
        status: "revoked",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info(
      `[HouseholdService] Owner ${callerUid} revoked invitation ` +
      `${invitationId} for household ${householdId}`
    );
  }

  /**
   * Returns the household's current valid invitation, if any. Owner only.
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Household id.
   * @return {Promise<HouseholdInvitationResult | null>} Active invitation.
   */
  static async getActiveInvitation(
    callerUid: string,
    householdId: string
  ): Promise<HouseholdInvitationResult | null> {
    const householdSnap = await db.collection(Collections.HOUSEHOLDS).doc(householdId).get();
    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }
    if (householdSnap.data()?.ownerId !== callerUid) {
      throwPermissionDenied("Chỉ chủ gia đình mới có quyền xem mã lời mời.");
    }

    const querySnap = await db
      .collection(Collections.HOUSEHOLD_INVITATIONS)
      .where("householdId", "==", householdId)
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (querySnap.empty) {
      return null;
    }

    const invDoc = querySnap.docs[0];
    const invData = invDoc.data();
    const expiresAt = (invData.expiresAt as Timestamp).toDate();

    if (expiresAt.getTime() <= Date.now()) {
      await invDoc.ref.update({
        status: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return null;
    }

    return {
      invitationId: invDoc.id,
      code: invData.code,
      householdId: invData.householdId,
      householdName: householdSnap.data()?.name || invData.householdName || "",
      expiresAt: expiresAt.toISOString(),
    };
  }

  /**
   * Removes a member from the household. Owner only; the owner cannot remove
   * themselves (BR-04). The removed member is moved back to their own
   * household and notified.
   * @param {string} callerUid Authenticated user id (owner).
   * @param {string} householdId Household id.
   * @param {string} memberUserId Member to remove.
   * @return {Promise<void>}
   */
  static async removeMember(
    callerUid: string,
    householdId: string,
    memberUserId: string
  ): Promise<void> {
    if (callerUid === memberUserId) {
      throwInvalidArgument("Chủ gia đình không thể tự xóa chính mình khỏi gia đình.");
    }

    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);

    await db.runTransaction(async (tx) => {
      const householdSnap = await tx.get(householdRef);
      if (!householdSnap.exists) {
        throwNotFound("Không tìm thấy thông tin gia đình.");
      }

      const householdData = householdSnap.data()!;
      if (householdData.ownerId !== callerUid) {
        throwPermissionDenied("Chỉ chủ gia đình mới có quyền xóa thành viên.");
      }

      const members: string[] = householdData.members || [];
      if (!members.includes(memberUserId)) {
        throwNotFound("Người dùng không thuộc gia đình này.");
      }

      await this.detachMember(tx, householdId, memberUserId);
      this.createSystemNotification(tx, memberUserId, householdId, {
        title: "Bạn đã bị xóa khỏi gia đình",
        message:
          `Chủ gia đình đã xóa bạn khỏi "${householdData.name || "gia đình"}". ` +
          "Bạn đã được chuyển về tủ lạnh của mình.",
      });
    });

    logger.info(
      `[HouseholdService] Owner ${callerUid} removed member ` +
      `${memberUserId} from household ${householdId}`
    );
  }

  /**
   * Voluntary leave by a non-owner member (FR-07). The owner cannot leave
   * their own household. The user is moved back to their own household.
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Household to leave.
   * @return {Promise<void>}
   */
  static async leaveHousehold(
    callerUid: string,
    householdId: string
  ): Promise<void> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);

    await db.runTransaction(async (tx) => {
      const householdSnap = await tx.get(householdRef);
      if (!householdSnap.exists) {
        throwNotFound("Không tìm thấy thông tin gia đình.");
      }

      const householdData = householdSnap.data()!;
      if (householdData.ownerId === callerUid) {
        throwFailedPrecondition(
          "Chủ gia đình không thể rời khỏi gia đình của chính mình."
        );
      }

      const members: string[] = householdData.members || [];
      if (!members.includes(callerUid)) {
        throwInvalidArgument("Bạn không phải là thành viên của gia đình này.");
      }

      await this.detachMember(tx, householdId, callerUid);
    });

    logger.info(
      `[HouseholdService] User ${callerUid} left household ${householdId}`
    );
  }

  /**
   * Switches the active household for the authenticated user (FR-08).
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Household to activate.
   * @return {Promise<void>}
   */
  static async switchHousehold(
    callerUid: string,
    householdId: string
  ): Promise<void> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const householdSnap = await householdRef.get();
    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }

    const members: string[] = householdSnap.data()?.members || [];
    if (!members.includes(callerUid)) {
      throwPermissionDenied("Bạn không thuộc gia đình này để có thể chuyển đổi.");
    }

    await db.collection(Collections.USERS).doc(callerUid).update({
      activeHouseholdId: householdId,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[HouseholdService] User ${callerUid} switched active household to ${householdId}`
    );
  }

  /**
   * Updates the household name (FR-02). Owner only.
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Household id.
   * @param {string} rawName New name.
   * @return {Promise<void>}
   */
  static async updateHouseholdName(
    callerUid: string,
    householdId: string,
    rawName: string
  ): Promise<void> {
    const name = rawName.trim();
    if (!name || name.length > 100) {
      throwInvalidArgument("Tên gia đình phải từ 1 đến 100 ký tự.");
    }

    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const householdSnap = await householdRef.get();
    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }

    if (householdSnap.data()?.ownerId !== callerUid) {
      throwPermissionDenied("Chỉ chủ gia đình mới có quyền đổi tên gia đình.");
    }

    await householdRef.update({
      name,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[HouseholdService] Owner ${callerUid} updated household ${householdId} name to "${name}"`
    );
  }

  /**
   * Returns the public profile (name, avatar, role) of every member.
   * Emails are never exposed to other members. Members only.
   * @param {string} callerUid Authenticated user id.
   * @param {string} householdId Household id.
   * @return {Promise<HouseholdMemberInfo[]>} Owner first, then caller.
   */
  static async getHouseholdMembers(
    callerUid: string,
    householdId: string
  ): Promise<HouseholdMemberInfo[]> {
    const householdSnap = await db.collection(Collections.HOUSEHOLDS).doc(householdId).get();
    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }

    const householdData = householdSnap.data()!;
    const members: string[] = householdData.members || [];
    const ownerId: string = householdData.ownerId || "";

    if (!members.includes(callerUid)) {
      throwPermissionDenied("Bạn không có quyền xem danh sách thành viên của gia đình này.");
    }

    const userSnaps = await db.getAll(
      ...members.map((uid) => db.collection(Collections.USERS).doc(uid))
    );

    const memberProfiles: HouseholdMemberInfo[] = userSnaps
      .filter((snap) => snap.exists)
      .map((snap) => {
        const udata = snap.data()!;
        return {
          id: snap.id,
          fullName: udata.fullName || "Thành viên FOORA",
          avatarUrl: udata.avatarUrl || null,
          role: snap.id === ownerId ? "owner" : "member",
          isCurrentUser: snap.id === callerUid,
        };
      });

    // Owner first, then the current user, then alphabetical by name.
    memberProfiles.sort((a, b) => {
      if (a.role !== b.role) return a.role === "owner" ? -1 : 1;
      if (a.isCurrentUser !== b.isCurrentUser) return a.isCurrentUser ? -1 : 1;
      return a.fullName.localeCompare(b.fullName);
    });

    return memberProfiles;
  }

  /**
   * Removes `uid` from the household and, when it was their active one,
   * points them back to the household they own (created if missing, same
   * shape as onUserCreated). Performs all its reads before any write, so
   * callers must finish their own reads first.
   * @param {Transaction} tx Running transaction.
   * @param {string} householdId Household being left.
   * @param {string} uid Member leaving.
   * @return {Promise<void>}
   */
  private static async detachMember(
    tx: Transaction,
    householdId: string,
    uid: string
  ): Promise<void> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const userRef = db.collection(Collections.USERS).doc(uid);

    const userSnap = await tx.get(userRef);
    const needsNewActive =
      userSnap.exists && userSnap.data()?.activeHouseholdId === householdId;
    const ownHouseholdSnap = needsNewActive ?
      await tx.get(
        db.collection(Collections.HOUSEHOLDS).where("ownerId", "==", uid).limit(1)
      ) :
      null;

    const serverTimestamp = FieldValue.serverTimestamp();
    tx.update(householdRef, {
      members: FieldValue.arrayRemove(uid),
      updatedAt: serverTimestamp,
    });

    if (!needsNewActive) {
      return;
    }

    let fallbackId = ownHouseholdSnap?.docs[0]?.id;
    if (!fallbackId) {
      const newHouseholdRef = db.collection(Collections.HOUSEHOLDS).doc();
      const fullName = userSnap.data()?.fullName || "tôi";
      tx.set(newHouseholdRef, {
        name: `Tủ lạnh của ${fullName}`,
        ownerId: uid,
        members: [uid],
        activeItemCount: 0,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
      fallbackId = newHouseholdRef.id;
    }

    tx.update(userRef, {
      activeHouseholdId: fallbackId,
      updatedAt: serverTimestamp,
    });
  }

  /**
   * Queues a `system` notification; onNotificationNew delivers the push.
   * @param {Transaction} tx Running transaction.
   * @param {string} userId Recipient.
   * @param {string} householdId Related household.
   * @param {object} content Title and message.
   */
  private static createSystemNotification(
    tx: Transaction,
    userId: string,
    householdId: string,
    content: {title: string; message: string}
  ): void {
    const ref = db
      .collection(Collections.USERS)
      .doc(userId)
      .collection(Collections.NOTIFICATIONS)
      .doc();
    tx.set(ref, {
      householdId,
      type: "system",
      title: content.title,
      message: content.message,
      inventoryItemId: null,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  /**
   * Resolves how many people a household may hold from its owner's active
   * plan (`memberships/{id}.memberLimit`), capped by MAX_HOUSEHOLD_MEMBERS.
   * @param {string} ownerId Household owner uid.
   * @return {Promise<HouseholdMemberLimit>} Seat limit and plan name.
   */
  private static async getMemberLimit(
    ownerId: string
  ): Promise<HouseholdMemberLimit> {
    const membershipId = await MembershipService.resolveMembershipId(ownerId);
    const {memberLimit, name} = await MembershipService.getLimits(membershipId);
    return {
      limit: Math.min(memberLimit ?? MAX_HOUSEHOLD_MEMBERS, MAX_HOUSEHOLD_MEMBERS),
      planName: name,
    };
  }

  /**
   * Tells the owner that someone could not join because the household is
   * full, so they can upgrade. The id is deterministic per household and
   * requester, so repeated attempts update one notification instead of
   * spamming pushes.
   * @param {string} ownerId Household owner uid.
   * @param {string} householdId Household id.
   * @param {string} householdName Household name.
   * @param {string} requesterUid User who tried to join.
   * @param {string} requesterName Display name of that user.
   * @return {Promise<void>}
   */
  private static async notifyOwnerHouseholdFull(
    ownerId: string,
    householdId: string,
    householdName: string,
    requesterUid: string,
    requesterName: string
  ): Promise<void> {
    await db
      .collection(Collections.USERS)
      .doc(ownerId)
      .collection(Collections.NOTIFICATIONS)
      .doc(`household_full_${householdId}_${requesterUid}`)
      .set({
        householdId,
        type: "system",
        title: "Gia đình đã đủ thành viên",
        message:
          `${requesterName} muốn tham gia "${householdName}" nhưng gia đình ` +
          "đã đủ chỗ. Nâng cấp Premium để mời thêm thành viên.",
        inventoryItemId: null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  }

  /**
   * Normalizes the code and rejects malformed input (counted as a failure).
   * @param {string} callerUid Authenticated user id.
   * @param {string} rawCode Code as typed by the user.
   * @return {Promise<string>} Normalized code.
   */
  private static async requireValidCodeFormat(
    callerUid: string,
    rawCode: string
  ): Promise<string> {
    const code = normalizeInviteCode(rawCode);
    if (!code) {
      throwInvalidArgument("Mã lời mời không được để trống.");
    }
    if (!isValidInviteCode(code)) {
      await this.recordFailedAttempt(callerUid);
      throwNotFound(INVALID_CODE_MESSAGE);
    }
    return code;
  }

  /**
   * Blocks users who entered too many wrong codes in the current window.
   * @param {string} uid Authenticated user id.
   * @return {Promise<void>}
   */
  private static async assertNotLockedOut(uid: string): Promise<void> {
    const snap = await db.collection(Collections.INVITE_ATTEMPTS).doc(uid).get();
    const data = snap.data();
    if (!data) return;

    const windowStart = (data.windowStart as Timestamp).toMillis();
    const inWindow = Date.now() - windowStart < INVITE_ATTEMPT_WINDOW_MS;
    if (inWindow && (data.failedCount as number) >= MAX_FAILED_INVITE_ATTEMPTS) {
      throwResourceExhausted(
        "Bạn nhập sai mã quá nhiều lần, vui lòng thử lại sau 1 giờ."
      );
    }
  }

  /**
   * Increments the wrong-code counter, starting a new window when expired.
   * @param {string} uid Authenticated user id.
   * @return {Promise<void>}
   */
  private static async recordFailedAttempt(uid: string): Promise<void> {
    const ref = db.collection(Collections.INVITE_ATTEMPTS).doc(uid);
    await db.runTransaction(async (tx) => {
      const data = (await tx.get(ref)).data();
      const windowStart = data ? (data.windowStart as Timestamp).toMillis() : 0;
      if (!data || Date.now() - windowStart >= INVITE_ATTEMPT_WINDOW_MS) {
        tx.set(ref, {failedCount: 1, windowStart: Timestamp.now()});
      } else {
        tx.update(ref, {failedCount: FieldValue.increment(1)});
      }
    });
  }

  /**
   * Resets the wrong-code counter after a successful join.
   * @param {string} uid Authenticated user id.
   * @return {Promise<void>}
   */
  private static async clearFailedAttempts(uid: string): Promise<void> {
    await db.collection(Collections.INVITE_ATTEMPTS).doc(uid).delete();
  }
}

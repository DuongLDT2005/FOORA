import * as crypto from "crypto";
import {FieldPath, FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {
  throwFailedPrecondition,
  throwInvalidArgument,
  throwNotFound,
  throwPermissionDenied,
} from "../../utils/errors";

export interface HouseholdMemberInfo {
  id: string;
  fullName: string;
  email: string;
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
  shareUrl: string;
}

export interface HouseholdInvitationPreview {
  code: string;
  householdId: string;
  householdName: string;
  ownerName: string;
  memberCount: number;
  alreadyMember: boolean;
  expiresAt: string;
}

export class HouseholdService {
  /**
   * Generates a new invitation code for a household.
   * Only the Household Owner can generate invitations (BR-03).
   */
  static async createInvitation(
    callerUid: string,
    householdId: string,
    expiresInDays = 7
  ): Promise<HouseholdInvitationResult> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const householdSnap = await householdRef.get();

    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }

    const householdData = householdSnap.data()!;
    if (householdData.ownerId !== callerUid) {
      throwPermissionDenied("Chỉ chủ gia đình mới có quyền tạo mã lời mời.");
    }

    // Revoke any existing active invitations for this household to keep a single active code
    const existingActiveQuery = await db
      .collection(Collections.HOUSEHOLD_INVITATIONS)
      .where("householdId", "==", householdId)
      .where("status", "==", "active")
      .get();

    const batch = db.batch();
    const serverTimestamp = FieldValue.serverTimestamp();
    for (const doc of existingActiveQuery.docs) {
      batch.update(doc.ref, {
        status: "revoked",
        updatedAt: serverTimestamp,
      });
    }

    // Generate unique 8-character uppercase alphanumeric code
    const rawCode = crypto.randomBytes(4).toString("hex").toUpperCase();
    const code = `FOORA-${rawCode}`;

    const now = new Date();
    const expiresAtDate = new Date(
      now.getTime() + expiresInDays * 24 * 60 * 60 * 1000
    );

    const newInvitationRef = db.collection(Collections.HOUSEHOLD_INVITATIONS).doc();
    const householdName = householdData.name || "Gia đình FOORA";

    batch.set(newInvitationRef, {
      code,
      householdId,
      householdName,
      createdBy: callerUid,
      status: "active",
      expiresAt: Timestamp.fromDate(expiresAtDate),
      createdAt: serverTimestamp,
      updatedAt: serverTimestamp,
    });

    await batch.commit();

    logger.info(
      `[HouseholdService] User ${callerUid} created invitation ${code} for household ${householdId}`
    );

    const shareUrl = `https://foora.app/household/join?code=${code}`;

    return {
      invitationId: newInvitationRef.id,
      code,
      householdId,
      householdName,
      expiresAt: expiresAtDate.toISOString(),
      shareUrl,
    };
  }

  /**
   * Retrieves invitation info for preview before the user accepts joining.
   */
  static async getInvitationInfo(
    callerUid: string,
    rawCode: string
  ): Promise<HouseholdInvitationPreview> {
    const code = rawCode.trim().toUpperCase();
    if (!code) {
      throwInvalidArgument("Mã lời mời không được để trống.");
    }

    const querySnap = await db
      .collection(Collections.HOUSEHOLD_INVITATIONS)
      .where("code", "==", code)
      .limit(1)
      .get();

    if (querySnap.empty) {
      throwNotFound("Mã lời mời không hợp lệ hoặc không tồn tại.");
    }

    const invDoc = querySnap.docs[0];
    const invData = invDoc.data();

    if (invData.status !== "active") {
      throwInvalidArgument(
        invData.status === "revoked" ?
          "Mã lời mời này đã bị chủ gia đình thu hồi." :
          "Mã lời mời này không còn hiệu lực."
      );
    }

    const expiresAt = (invData.expiresAt as Timestamp).toDate();
    if (expiresAt.getTime() <= Date.now()) {
      // Mark as expired in the background
      await invDoc.ref.update({
        status: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      });
      throwInvalidArgument("Mã lời mời này đã hết hạn.");
    }

    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(invData.householdId);
    const householdSnap = await householdRef.get();
    if (!householdSnap.exists) {
      throwNotFound("Gia đình liên kết với lời mời này không còn tồn tại.");
    }

    const householdData = householdSnap.data()!;
    const members: string[] = householdData.members || [];
    const alreadyMember = members.includes(callerUid);

    let ownerName = "Chủ gia đình";
    if (householdData.ownerId) {
      const ownerSnap = await db
        .collection(Collections.USERS)
        .doc(householdData.ownerId)
        .get();
      if (ownerSnap.exists) {
        ownerName = ownerSnap.data()?.fullName || ownerName;
      }
    }

    return {
      code: invData.code,
      householdId: invData.householdId,
      householdName: householdData.name || invData.householdName,
      ownerName,
      memberCount: members.length,
      alreadyMember,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /**
   * Joins a household using a valid invitation code (BR-04, BR-05, BR-06).
   */
  static async joinHousehold(
    callerUid: string,
    rawCode: string
  ): Promise<{householdId: string; householdName: string}> {
    const code = rawCode.trim().toUpperCase();
    if (!code) {
      throwInvalidArgument("Mã lời mời không được để trống.");
    }

    const querySnap = await db
      .collection(Collections.HOUSEHOLD_INVITATIONS)
      .where("code", "==", code)
      .limit(1)
      .get();

    if (querySnap.empty) {
      throwNotFound("Mã lời mời không hợp lệ hoặc không tồn tại.");
    }

    const invDoc = querySnap.docs[0];
    const invData = invDoc.data();

    if (invData.status !== "active") {
      throwInvalidArgument("Mã lời mời đã bị thu hồi hoặc không còn hiệu lực.");
    }

    const expiresAt = (invData.expiresAt as Timestamp).toDate();
    if (expiresAt.getTime() <= Date.now()) {
      await invDoc.ref.update({
        status: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      });
      throwInvalidArgument("Mã lời mời đã hết hạn.");
    }

    const householdId: string = invData.householdId;
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const userRef = db.collection(Collections.USERS).doc(callerUid);

    let householdName = "";

    await db.runTransaction(async (tx) => {
      const householdSnap = await tx.get(householdRef);
      if (!householdSnap.exists) {
        throwNotFound("Gia đình không tồn tại.");
      }

      const householdData = householdSnap.data()!;
      householdName = householdData.name || "Gia đình FOORA";
      const members: string[] = householdData.members || [];

      if (members.includes(callerUid)) {
        throwInvalidArgument("Bạn đã là thành viên của gia đình này.");
      }

      const serverTimestamp = FieldValue.serverTimestamp();

      // Add user to household members list
      tx.update(householdRef, {
        members: FieldValue.arrayUnion(callerUid),
        updatedAt: serverTimestamp,
      });

      // Switch newly joined household as activeHouseholdId
      tx.update(userRef, {
        activeHouseholdId: householdId,
        updatedAt: serverTimestamp,
      });
    });

    logger.info(
      `[HouseholdService] User ${callerUid} successfully joined household ${householdId} (${householdName})`
    );

    return {householdId, householdName};
  }

  /**
   * Revokes an active invitation.
   * Only Household Owner can revoke invitations (BR-03).
   */
  static async revokeInvitation(
    callerUid: string,
    householdId: string,
    invitationId: string
  ): Promise<void> {
    const householdSnap = await db.collection(Collections.HOUSEHOLDS).doc(householdId).get();
    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }
    if (householdSnap.data()?.ownerId !== callerUid) {
      throwPermissionDenied("Chỉ chủ gia đình mới có quyền thu hồi lời mời.");
    }

    const invRef = db.collection(Collections.HOUSEHOLD_INVITATIONS).doc(invitationId);
    const invSnap = await invRef.get();
    if (!invSnap.exists) {
      throwNotFound("Không tìm thấy lời mời.");
    }

    await invRef.update({
      status: "revoked",
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[HouseholdService] Owner ${callerUid} revoked invitation ${invitationId} for household ${householdId}`
    );
  }

  /**
   * Retrieves the current active invitation for a household if any.
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
      householdName: invData.householdName || householdSnap.data()?.name || "",
      expiresAt: expiresAt.toISOString(),
      shareUrl: `https://foora.app/household/join?code=${invData.code}`,
    };
  }

  /**
   * Removes a member from the household.
   * Only Household Owner can remove members (BR-04).
   * Owner cannot remove themselves (BR-04, FR-05).
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
    const householdSnap = await householdRef.get();
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

    const serverTimestamp = FieldValue.serverTimestamp();
    const memberUserRef = db.collection(Collections.USERS).doc(memberUserId);

    await db.runTransaction(async (tx) => {
      // 1. Remove member from household members list
      tx.update(householdRef, {
        members: FieldValue.arrayRemove(memberUserId),
        updatedAt: serverTimestamp,
      });

      // 2. If the removed user's active household was this one, redirect them to another household
      const memberUserSnap = await tx.get(memberUserRef);
      if (
        memberUserSnap.exists &&
        memberUserSnap.data()?.activeHouseholdId === householdId
      ) {
        // Query other households the member belongs to
        const otherHouseholdsSnap = await db
          .collection(Collections.HOUSEHOLDS)
          .where("members", "array-contains", memberUserId)
          .limit(2)
          .get();

        const fallbackHousehold = otherHouseholdsSnap.docs.find(
          (doc) => doc.id !== householdId
        );

        if (fallbackHousehold) {
          tx.update(memberUserRef, {
            activeHouseholdId: fallbackHousehold.id,
            updatedAt: serverTimestamp,
          });
        } else {
          // If no other household, create a new personal default household for the member
          const newPersonalHouseholdRef = db.collection(Collections.HOUSEHOLDS).doc();
          const memberName = memberUserSnap.data()?.fullName || "tôi";
          tx.set(newPersonalHouseholdRef, {
            name: `Tủ lạnh của ${memberName}`,
            ownerId: memberUserId,
            members: [memberUserId],
            activeItemCount: 0,
            createdAt: serverTimestamp,
            updatedAt: serverTimestamp,
          });

          tx.update(memberUserRef, {
            activeHouseholdId: newPersonalHouseholdRef.id,
            updatedAt: serverTimestamp,
          });
        }
      }
    });

    logger.info(
      `[HouseholdService] Owner ${callerUid} removed member ${memberUserId} from household ${householdId}`
    );
  }

  /**
   * Voluntary leave of a household by a member (FR-07, BR-12).
   * Owner cannot leave without transferring ownership (BR-12).
   */
  static async leaveHousehold(
    callerUid: string,
    householdId: string
  ): Promise<void> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const householdSnap = await householdRef.get();
    if (!householdSnap.exists) {
      throwNotFound("Không tìm thấy thông tin gia đình.");
    }

    const householdData = householdSnap.data()!;
    if (householdData.ownerId === callerUid) {
      throwFailedPrecondition(
        "Chủ gia đình không thể rời gia đình. Bạn cần chuyển quyền sở hữu trước."
      );
    }

    const members: string[] = householdData.members || [];
    if (!members.includes(callerUid)) {
      throwInvalidArgument("Bạn không phải là thành viên của gia đình này.");
    }

    const serverTimestamp = FieldValue.serverTimestamp();
    const callerUserRef = db.collection(Collections.USERS).doc(callerUid);

    await db.runTransaction(async (tx) => {
      // 1. Remove caller from members
      tx.update(householdRef, {
        members: FieldValue.arrayRemove(callerUid),
        updatedAt: serverTimestamp,
      });

      // 2. If activeHousehold was this one, switch to another or recreate personal default
      const callerUserSnap = await tx.get(callerUserRef);
      if (
        callerUserSnap.exists &&
        callerUserSnap.data()?.activeHouseholdId === householdId
      ) {
        const otherHouseholdsSnap = await db
          .collection(Collections.HOUSEHOLDS)
          .where("members", "array-contains", callerUid)
          .limit(2)
          .get();

        const fallback = otherHouseholdsSnap.docs.find(
          (doc) => doc.id !== householdId
        );

        if (fallback) {
          tx.update(callerUserRef, {
            activeHouseholdId: fallback.id,
            updatedAt: serverTimestamp,
          });
        } else {
          const newHouseholdRef = db.collection(Collections.HOUSEHOLDS).doc();
          const callerName = callerUserSnap.data()?.fullName || "tôi";
          tx.set(newHouseholdRef, {
            name: `Tủ lạnh của ${callerName}`,
            ownerId: callerUid,
            members: [callerUid],
            activeItemCount: 0,
            createdAt: serverTimestamp,
            updatedAt: serverTimestamp,
          });

          tx.update(callerUserRef, {
            activeHouseholdId: newHouseholdRef.id,
            updatedAt: serverTimestamp,
          });
        }
      }
    });

    logger.info(
      `[HouseholdService] User ${callerUid} left household ${householdId}`
    );
  }

  /**
   * Switches the active household for the authenticated user (FR-08, BR-09).
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
   * Updates household name (FR-02).
   * Only Household Owner can update name.
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
   * Retrieves public profile list of all members in a household (FR-01, FR-05).
   * Only members can view member list.
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

    if (members.length === 0) {
      return [];
    }

    // Fetch user profiles in batches of 30 (Firestore in constraint limit)
    const memberProfiles: HouseholdMemberInfo[] = [];
    const chunkSize = 30;

    for (let i = 0; i < members.length; i += chunkSize) {
      const chunk = members.slice(i, i + chunkSize);
      const usersSnap = await db
        .collection(Collections.USERS)
        .where(FieldPath.documentId(), "in", chunk)
        .get();

      for (const userDoc of usersSnap.docs) {
        const udata = userDoc.data();
        const uid = userDoc.id;
        memberProfiles.push({
          id: uid,
          fullName: udata.fullName || "Thành viên FOORA",
          email: udata.email || "",
          avatarUrl: udata.avatarUrl || null,
          role: uid === ownerId ? "owner" : "member",
          isCurrentUser: uid === callerUid,
        });
      }
    }

    // Sort: Owner first, then current user, then alphabetical by fullName
    memberProfiles.sort((a, b) => {
      if (a.role === "owner") return -1;
      if (b.role === "owner") return 1;
      if (a.isCurrentUser) return -1;
      if (b.isCurrentUser) return 1;
      return a.fullName.localeCompare(b.fullName);
    });

    return memberProfiles;
  }
}

import {FieldValue, WriteBatch} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {
  MAX_HOUSEHOLD_MEMBERS,
  pickLockedItemIds,
  pickLockedMembers,
} from "./entitlement";
import {MembershipService} from "./membership_service";

const WRITE_CHUNK_SIZE = 400;

export interface HouseholdEnforcementResult {
  householdId: string;
  householdName: string;
  lockedMemberCount: number;
  lockedItemCount: number;
  newlyLockedMembers: string[];
  newlyUnlockedMembers: string[];
}

/**
 * Keeps a household inside its owner's plan: members and active items above
 * the plan limits are locked (`households.lockedMembers`,
 * `inventory_items.isLocked`) and unlocked again once the owner upgrades or
 * a slot frees up. Idempotent, so it is safe to run after any change.
 */
export class PlanEnforcementService {
  /**
   * Enforces every household owned by [ownerId].
   * @param {string} ownerId Owner uid whose plan changed.
   * @return {Promise<HouseholdEnforcementResult[]>} One result per household.
   */
  static async enforceForOwner(
    ownerId: string
  ): Promise<HouseholdEnforcementResult[]> {
    const households = await db.collection(Collections.HOUSEHOLDS)
      .where("ownerId", "==", ownerId)
      .get();
    const results: HouseholdEnforcementResult[] = [];
    for (const household of households.docs) {
      const result = await this.enforceHousehold(household.id);
      if (result) results.push(result);
    }
    return results;
  }

  /**
   * Recomputes which members and items of one household are locked.
   * @param {string} householdId Household id.
   * @return {Promise<HouseholdEnforcementResult | null>} Null if missing.
   */
  static async enforceHousehold(
    householdId: string
  ): Promise<HouseholdEnforcementResult | null> {
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const householdSnap = await householdRef.get();
    const data = householdSnap.data();
    if (!householdSnap.exists || !data || typeof data.ownerId !== "string") {
      return null;
    }
    const ownerId = data.ownerId;
    const householdName = (data.name as string) || "gia đình";
    const membershipId = await MembershipService.resolveMembershipId(ownerId);
    const {memberLimit, foodLimit} =
      await MembershipService.getLimits(membershipId);

    const members: string[] = Array.isArray(data.members) ? data.members : [];
    const previousLocked: string[] = Array.isArray(data.lockedMembers) ?
      data.lockedMembers : [];
    const seatLimit = Math.min(
      memberLimit ?? MAX_HOUSEHOLD_MEMBERS,
      MAX_HOUSEHOLD_MEMBERS
    );
    const lockedMembers = pickLockedMembers(members, ownerId, seatLimit);
    const newlyLockedMembers = lockedMembers
      .filter((uid) => !previousLocked.includes(uid));
    const newlyUnlockedMembers = previousLocked
      .filter((uid) => members.includes(uid) && !lockedMembers.includes(uid));

    const activeItems = await householdRef
      .collection(Collections.INVENTORY_ITEMS)
      .where("status", "==", "active")
      .get();
    const lockedItemIds = new Set(pickLockedItemIds(
      activeItems.docs.map((doc) => ({
        id: doc.id,
        createdAtMillis: doc.get("createdAt")?.toMillis?.() ?? 0,
      })),
      foodLimit
    ));

    const writes: ((batch: WriteBatch) => void)[] = [];
    for (const item of activeItems.docs) {
      const shouldLock = lockedItemIds.has(item.id);
      if ((item.get("isLocked") === true) !== shouldLock) {
        writes.push((batch) => batch.update(item.ref, {isLocked: shouldLock}));
      }
    }

    const membersChanged = newlyLockedMembers.length > 0 ||
      newlyUnlockedMembers.length > 0 ||
      previousLocked.length !== lockedMembers.length;
    if (membersChanged || data.lockedItemCount !== lockedItemIds.size) {
      writes.push((batch) => batch.update(householdRef, {
        lockedMembers,
        lockedItemCount: lockedItemIds.size,
        updatedAt: FieldValue.serverTimestamp(),
      }));
    }

    for (const uid of newlyLockedMembers) {
      await this.moveOffLockedHousehold(uid, householdId, writes);
      writes.push((batch) => this.notify(batch, uid, householdId, {
        title: "Bạn tạm thời bị khóa khỏi gia đình",
        message:
          `Gói Premium của chủ "${householdName}" đã hết hạn nên gia đình ` +
          "chỉ còn đủ chỗ theo gói Free. Bạn đã được chuyển về tủ lạnh của " +
          "mình và sẽ được mở lại khi chủ gia đình gia hạn Premium.",
      }));
    }
    for (const uid of newlyUnlockedMembers) {
      writes.push((batch) => this.notify(batch, uid, householdId, {
        title: "Bạn đã được mở khóa",
        message: `Bạn có thể dùng lại tủ lạnh "${householdName}".`,
      }));
    }

    for (let i = 0; i < writes.length; i += WRITE_CHUNK_SIZE) {
      const batch = db.batch();
      writes.slice(i, i + WRITE_CHUNK_SIZE).forEach((write) => write(batch));
      await batch.commit();
    }

    if (writes.length > 0) {
      logger.info("[PlanEnforcement] Household limits applied", {
        householdId,
        membershipId,
        lockedMembers: lockedMembers.length,
        lockedItems: lockedItemIds.size,
      });
    }

    return {
      householdId,
      householdName,
      lockedMemberCount: lockedMembers.length,
      lockedItemCount: lockedItemIds.size,
      newlyLockedMembers,
      newlyUnlockedMembers,
    };
  }

  /**
   * Points a locked member whose active household is [householdId] back to
   * the household they own, creating one if missing (same shape as
   * onUserCreated).
   * @param {string} uid Locked member.
   * @param {string} householdId Household they are locked out of.
   * @param {Function[]} writes Pending batch writes to append to.
   * @return {Promise<void>}
   */
  private static async moveOffLockedHousehold(
    uid: string,
    householdId: string,
    writes: ((batch: WriteBatch) => void)[]
  ): Promise<void> {
    const userRef = db.collection(Collections.USERS).doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists || userSnap.get("activeHouseholdId") !== householdId) {
      return;
    }
    const own = await db.collection(Collections.HOUSEHOLDS)
      .where("ownerId", "==", uid)
      .limit(1)
      .get();
    let fallbackId = own.docs[0]?.id;
    if (!fallbackId) {
      const newHouseholdRef = db.collection(Collections.HOUSEHOLDS).doc();
      const fullName = userSnap.get("fullName") || "tôi";
      writes.push((batch) => batch.set(newHouseholdRef, {
        name: `Tủ lạnh của ${fullName}`,
        ownerId: uid,
        members: [uid],
        activeItemCount: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }));
      fallbackId = newHouseholdRef.id;
    }
    const target = fallbackId;
    writes.push((batch) => batch.update(userRef, {
      activeHouseholdId: target,
      updatedAt: FieldValue.serverTimestamp(),
    }));
  }

  private static notify(
    batch: WriteBatch,
    userId: string,
    householdId: string,
    content: {title: string; message: string}
  ): void {
    batch.set(
      db.collection(Collections.USERS).doc(userId)
        .collection(Collections.NOTIFICATIONS).doc(),
      {
        householdId,
        type: "system",
        title: content.title,
        message: content.message,
        inventoryItemId: null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      }
    );
  }
}

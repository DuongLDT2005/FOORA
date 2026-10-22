import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {throwFailedPrecondition} from "../../utils/errors";
import {resolveMembershipId} from "./entitlement";

/** Limits configured in `memberships/{membershipId}`; `null` = unlimited. */
export interface MembershipLimits {
  membershipId: string;
  name: string;
  foodLimit: number | null;
  receiptScanQuota: number | null;
  /** Max people in a household owned by this plan, owner included. */
  memberLimit: number | null;
}

/**
 * Single entitlement resolver for every module (inventory limits, receipt
 * quota, auth). Never trusts the cached `users.membershipId`.
 */
export class MembershipService {
  /**
   * Resolves the user's plan from their active subscriptions.
   * @param {string} uid User id.
   * @param {Date} now Server time.
   * @return {Promise<string>} Effective membership id.
   */
  static async resolveMembershipId(
    uid: string,
    now: Date = new Date()
  ): Promise<string> {
    const snapshot = await db
      .collection(Collections.USERS)
      .doc(uid)
      .collection(Collections.SUBSCRIPTIONS)
      .where("status", "==", "active")
      .get();
    return resolveMembershipId(
      snapshot.docs.map((doc) => doc.data()),
      now.getTime()
    );
  }

  /**
   * Reads plan limits from `memberships/{membershipId}`. A missing or
   * inactive plan is a configuration error, never a silent default.
   * @param {string} membershipId Membership id.
   * @return {Promise<MembershipLimits>} Configured limits.
   */
  static async getLimits(membershipId: string): Promise<MembershipLimits> {
    const doc = await db
      .collection(Collections.MEMBERSHIPS)
      .doc(membershipId)
      .get();
    const data = doc.data();
    if (!doc.exists || data === undefined || data.isActive === false) {
      logger.error(`[MembershipService] Missing membership "${membershipId}"`);
      throwFailedPrecondition(
        "Cấu hình gói thành viên chưa sẵn sàng. Vui lòng thử lại sau."
      );
    }
    return {
      membershipId,
      name: typeof data.name === "string" ? data.name : membershipId,
      foodLimit: typeof data.foodLimit === "number" ? data.foodLimit : null,
      receiptScanQuota: typeof data.receiptScanQuota === "number" ?
        data.receiptScanQuota : null,
      memberLimit: typeof data.memberLimit === "number" ?
        data.memberLimit : null,
    };
  }

  /**
   * Recomputes the derived `users.membershipId` cache from subscriptions.
   * @param {string} uid User id.
   * @param {Date} now Server time.
   * @return {Promise<string>} The membership id written to the cache.
   */
  static async syncMembershipCache(
    uid: string,
    now: Date = new Date()
  ): Promise<string> {
    const membershipId = await MembershipService.resolveMembershipId(uid, now);
    await db.collection(Collections.USERS).doc(uid).update({
      membershipId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return membershipId;
  }
}

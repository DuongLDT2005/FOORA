import {FieldValue} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION} from "../../config/firebase";
import * as logger from "firebase-functions/logger";
import {Collections} from "../../constants/collections";
import {MembershipIds} from "../../membership/services/entitlement";
import {MembershipService} from "../../membership/services/membership_service";
import {
  HouseholdEnforcementResult,
  PlanEnforcementService,
} from "../../membership/services/plan_enforcement";

/**
 * Tells the owner their Premium ended and what was locked because of it.
 * @param {string} uid Owner whose Premium expired.
 * @param {HouseholdEnforcementResult[]} households Enforcement results.
 * @return {Promise<void>}
 */
async function notifyPremiumExpired(
  uid: string,
  households: HouseholdEnforcementResult[]
): Promise<void> {
  const lockedMembers = households
    .reduce((total, item) => total + item.lockedMemberCount, 0);
  const lockedItems = households
    .reduce((total, item) => total + item.lockedItemCount, 0);
  const locked = [
    lockedMembers > 0 ? `${lockedMembers} thành viên` : null,
    lockedItems > 0 ? `${lockedItems} món` : null,
  ].filter((part) => part !== null);
  const message = locked.length > 0 ?
    `Tài khoản đã về gói Free. ${locked.join(" và ")} vượt giới hạn gói ` +
      "Free đã bị khóa. Gia hạn Premium để mở khóa lại." :
    "Tài khoản đã về gói Free. Gia hạn Premium để tiếp tục dùng các " +
      "quyền lợi không giới hạn.";
  await db.collection(Collections.USERS).doc(uid)
    .collection(Collections.NOTIFICATIONS).doc()
    .set({
      householdId: households[0]?.householdId ?? null,
      type: "system",
      title: "Gói Premium đã hết hạn",
      message,
      inventoryItemId: null,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
}

export const expirePendingPayments = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Ho_Chi_Minh",
  },
  async () => {
    const payments = await db.collectionGroup(Collections.PAYMENTS)
      .where("status", "==", "pending")
      .where("expiresAt", "<=", new Date())
      .limit(200)
      .get();

    if (!payments.empty) {
      const paymentBatch = db.batch();
      for (const payment of payments.docs) {
        paymentBatch.update(payment.ref, {
          status: "expired",
          updatedAt: FieldValue.serverTimestamp(),
        });
        const reference = payment.data().referenceNumber;
        if (typeof reference === "string") {
          paymentBatch.update(
            db.collection(Collections.PAYMENT_REFERENCES).doc(reference),
            {status: "expired"}
          );
        }
      }
      await paymentBatch.commit();
    }

    const subscriptions = await db.collectionGroup(Collections.SUBSCRIPTIONS)
      .where("status", "==", "active")
      .where("endDate", "<=", new Date())
      .limit(100)
      .get();

    if (!subscriptions.empty) {
      const subscriptionBatch = db.batch();
      const affectedUserIds = new Set<string>();
      for (const subscription of subscriptions.docs) {
        subscriptionBatch.update(subscription.ref, {
          status: "expired",
          updatedAt: FieldValue.serverTimestamp(),
        });
        const userRef = subscription.ref.parent.parent;
        if (userRef !== null) affectedUserIds.add(userRef.id);
      }
      await subscriptionBatch.commit();

      // Recompute the derived cache: only downgrade users with no other
      // active subscription, then lock what exceeds the Free plan.
      const userIds = [...affectedUserIds];
      const results = await Promise.allSettled(
        userIds.map(async (uid) => {
          const membershipId = await MembershipService.syncMembershipCache(uid);
          if (membershipId !== MembershipIds.FREE) return;
          const households = await PlanEnforcementService.enforceForOwner(uid);
          await notifyPremiumExpired(uid, households);
        })
      );
      results.forEach((result, index) => {
        if (result.status === "rejected") {
          logger.error(
            "[expirePendingPayments] membership downgrade failed",
            {uid: userIds[index], error: result.reason}
          );
        }
      });
    }
  }
);

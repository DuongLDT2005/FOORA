import {FieldValue} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION} from "../../config/firebase";
import * as logger from "firebase-functions/logger";
import {Collections} from "../../constants/collections";
import {MembershipService} from "../../membership/services/membership_service";

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
      // active subscription.
      const results = await Promise.allSettled(
        [...affectedUserIds].map((uid) =>
          MembershipService.syncMembershipCache(uid))
      );
      results.forEach((result, index) => {
        if (result.status === "rejected") {
          logger.error(
            "[expirePendingPayments] membership cache sync failed",
            {uid: [...affectedUserIds][index], error: result.reason}
          );
        }
      });
    }
  }
);

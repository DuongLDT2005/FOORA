import {FieldValue} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION} from "../../config/firebase";
import {Collections} from "../../constants/collections";

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
      for (const subscription of subscriptions.docs) {
        subscriptionBatch.update(subscription.ref, {
          status: "expired",
          updatedAt: FieldValue.serverTimestamp(),
        });
        const userRef = subscription.ref.parent.parent;
        if (userRef !== null) {
          subscriptionBatch.update(userRef, {
            membershipId: "free",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      await subscriptionBatch.commit();
    }
  }
);

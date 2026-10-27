import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION} from "../../config/firebase";
import {Collections} from "../../constants/collections";

export const cleanupExpiredAiRequests = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Ho_Chi_Minh",
  },
  async () => {
    const expired = await db.collectionGroup(Collections.AI_REQUESTS)
      .where("status", "==", "pending")
      .where("leaseExpiresAt", "<", Timestamp.now())
      .limit(100).get();
    let refunded = 0;
    for (const item of expired.docs) {
      const userRef = item.ref.parent.parent;
      if (!userRef) continue;
      await db.runTransaction(async (tx) => {
        const current = await tx.get(item.ref);
        const data = current.data();
        if (data?.status !== "pending" ||
            data.leaseExpiresAt?.toMillis() >= Date.now()) return;
        const day = data.quotaDay;
        if (typeof day !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(day)) {
          logger.error("[cleanupExpiredAiRequests] Invalid quota day", item.ref.path);
          return;
        }
        const usageRef = userRef.collection(Collections.AI_USAGE_DAYS).doc(day);
        const usage = await tx.get(usageRef);
        if (data.quotaReserved === true) {
          tx.set(usageRef, {
            used: Math.max(0, Number(usage.data()?.used ?? 0) - 1),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        tx.update(item.ref, {
          status: "failed",
          quotaReserved: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
        refunded++;
      });
    }
    logger.info(`[cleanupExpiredAiRequests] refunded=${refunded}`);
  }
);

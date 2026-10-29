import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {refundExpiredAiRequests} from "../../ai/services/ai_request_cleanup";
import {expireOverduePayments} from "../../payment/services/payment_expiry";

/**
 * Every-5-minute sweep for things that expire: AI request leases and
 * pending payments / Premium subscriptions. One job instead of two keeps
 * the project within Cloud Scheduler's free tier. Each part runs on its
 * own, so a failure in one does not skip the other.
 */
export const maintenanceSweepCron = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Ho_Chi_Minh",
    timeoutSeconds: 240,
  },
  async () => {
    const [ai, payments] = await Promise.allSettled([
      refundExpiredAiRequests(),
      expireOverduePayments(),
    ]);
    if (ai.status === "rejected") {
      logger.error("[maintenanceSweepCron] AI request cleanup failed", ai.reason);
    }
    if (payments.status === "rejected") {
      logger.error("[maintenanceSweepCron] payment expiry failed", payments.reason);
    }
    logger.info(
      "[maintenanceSweepCron] " +
        `aiRefunded=${ai.status === "fulfilled" ? ai.value : "error"} ` +
        `payments=${payments.status}`
    );
  }
);

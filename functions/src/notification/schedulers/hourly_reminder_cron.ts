import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {db, REGION} from "../../config/firebase";
import {ExpiryService} from "../../inventory/services/expiry_service";
import {sendPremiumExpiryReminders} from "../../membership/services/premium_reminder";
import {vnClock} from "../services/notification_settings";
import {ShoppingReminderService} from "../services/shopping_reminder_service";

/**
 * The only reminder job: expiry alerts and the weekly shopping reminder are
 * both sent at each user's chosen reminderHour (Vietnam time); Premium
 * expiry reminders are checked every hour so the final-day one lands well
 * before the plan ends. Each part runs on its own, so a failure in one does
 * not skip the others.
 */
export const hourlyReminderCron = onSchedule(
  {
    region: REGION,
    schedule: "0 * * * *",
    timeZone: "Asia/Ho_Chi_Minh",
    timeoutSeconds: 540,
  },
  async () => {
    const now = new Date();
    const [expiry, shopping, premium] = await Promise.allSettled([
      new ExpiryService(db).runForHour(now, vnClock(now).hour),
      ShoppingReminderService.run(now),
      sendPremiumExpiryReminders(now),
    ]);
    const parts: string[] = [];
    if (expiry.status === "fulfilled") {
      parts.push(`expiry created=${expiry.value.created} skipped=${expiry.value.skipped}`);
    } else {
      logger.error("[hourlyReminderCron] expiry reminders failed", expiry.reason);
    }
    if (shopping.status === "fulfilled") {
      parts.push(
        `shopping created=${shopping.value.created} skipped=${shopping.value.skipped}`
      );
    } else {
      logger.error("[hourlyReminderCron] shopping reminders failed", shopping.reason);
    }
    if (premium.status === "fulfilled") {
      parts.push(`premium created=${premium.value}`);
    } else {
      logger.error("[hourlyReminderCron] premium reminders failed", premium.reason);
    }
    logger.info(`[hourlyReminderCron] ${parts.join("; ")}`);
  }
);

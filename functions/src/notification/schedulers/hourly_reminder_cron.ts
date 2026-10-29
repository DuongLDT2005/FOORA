import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {db, REGION} from "../../config/firebase";
import {ExpiryService} from "../../inventory/services/expiry_service";
import {vnClock} from "../services/notification_settings";
import {ShoppingReminderService} from "../services/shopping_reminder_service";

/**
 * The only reminder job: expiry alerts and the weekly shopping reminder are
 * both sent at each user's chosen reminderHour (Vietnam time).
 */
export const hourlyReminderCron = onSchedule(
  {region: REGION, schedule: "0 * * * *", timeZone: "Asia/Ho_Chi_Minh"},
  async () => {
    const now = new Date();
    const expiry = await new ExpiryService(db).runForHour(now, vnClock(now).hour);
    const shopping = await ShoppingReminderService.run(now);
    logger.info(
      `[hourlyReminderCron] expiry created=${expiry.created} skipped=${expiry.skipped}; ` +
      `shopping created=${shopping.created} skipped=${shopping.skipped}`
    );
  }
);

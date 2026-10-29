import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {sendPremiumExpiryReminders} from "../services/premium_reminder";

// Hourly, so the final-day reminder lands well before the plan ends.
export const premiumExpiryReminderCron = onSchedule(
  {
    region: REGION,
    schedule: "0 * * * *",
    timeZone: "Asia/Ho_Chi_Minh",
  },
  async () => {
    const created = await sendPremiumExpiryReminders(new Date());
    logger.info(`[premiumExpiryReminderCron] created=${created}`);
  }
);

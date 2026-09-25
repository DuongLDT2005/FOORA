import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {db, REGION} from "../../config/firebase";
import {ExpiryService} from "../services/expiry_service";

export const checkExpiryDailyCron = onSchedule(
  {
    region: REGION,
    schedule: "0 7 * * *",
    timeZone: "Asia/Ho_Chi_Minh",
  },
  async () => {
    const result = await new ExpiryService(db).run(new Date());
    logger.info(
      `[checkExpiryDailyCron] created=${result.created} skipped=${result.skipped}`
    );
  }
);

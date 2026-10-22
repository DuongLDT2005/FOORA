import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {REGION} from "../config/firebase";
import {ga4DemoApiSecret, ga4DemoMeasurementId, ga4DemoStartDate} from "./config";
import {planDay, sendDay, vnDateOf} from "./synthetic_traffic";

/**
 * Pushes one day of synthetic demo traffic to the demo GA4 property.
 * Runs late in the evening so the whole day's sessions are in the past.
 */
export const syntheticAnalyticsDailyCron = onSchedule(
  {
    region: REGION,
    schedule: "50 23 * * *",
    timeZone: "Asia/Ho_Chi_Minh",
    secrets: [ga4DemoApiSecret],
  },
  async () => {
    const measurementId = ga4DemoMeasurementId.value();
    if (!measurementId) {
      logger.info("[syntheticAnalyticsDailyCron] disabled (no measurement id)");
      return;
    }

    const plan = planDay(
      {startDate: ga4DemoStartDate.value()},
      vnDateOf(Date.now())
    );
    const sent = await sendDay(plan, {
      measurementId,
      apiSecret: ga4DemoApiSecret.value(),
    });
    logger.info(
      `[syntheticAnalyticsDailyCron] date=${plan.date} day=${plan.dayIndex} ` +
        `users=${plan.totalUsers} active=${plan.activeUsers} ` +
        `sessions=${plan.sessions} events=${sent}`
    );
  }
);

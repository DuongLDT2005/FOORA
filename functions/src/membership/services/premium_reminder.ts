import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {toMillis} from "./entitlement";

const DAY_MS = 86400000;
/** Firestore gRPC code for a `create()` on an existing document. */
const ALREADY_EXISTS = 6;

export type PremiumReminderStage = "3d" | "1d";

/**
 * Which reminder a subscription ending at [endMillis] is due for: one about
 * three days ahead and a last one within the final day.
 * @param {number} endMillis Subscription end.
 * @param {number} nowMillis Current time.
 * @return {PremiumReminderStage | null} Due stage, or null.
 */
export function premiumReminderStage(
  endMillis: number,
  nowMillis: number
): PremiumReminderStage | null {
  const left = endMillis - nowMillis;
  if (left <= 0 || left > 3 * DAY_MS) return null;
  return left <= DAY_MS ? "1d" : "3d";
}

/**
 * Builds the reminder text for a subscription ending at [endDate].
 * @param {Date} endDate Subscription end.
 * @param {PremiumReminderStage} stage Reminder stage.
 * @return {{title: string, message: string}} Notification content.
 */
export function premiumReminderContent(
  endDate: Date,
  stage: PremiumReminderStage
): {title: string; message: string} {
  const when = endDate.toLocaleString("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
  return {
    title: stage === "1d" ?
      "Premium hết hạn trong 24 giờ tới" :
      "Premium sắp hết hạn",
    message:
      `Gói Premium của bạn hết hạn lúc ${when}. Gia hạn để giữ thành viên ` +
      "và món vượt giới hạn gói Free không bị khóa.",
  };
}

/**
 * Sends the due expiry reminders. Each notification id is tied to the
 * subscription, its end date and the stage, so a reminder is sent once per
 * period even if the job reruns, and renewing (which moves `endDate`)
 * starts a fresh cycle.
 * @param {Date} now Current time.
 * @return {Promise<number>} Reminders created.
 */
export async function sendPremiumExpiryReminders(
  now: Date = new Date()
): Promise<number> {
  const subscriptions = await db.collectionGroup(Collections.SUBSCRIPTIONS)
    .where("status", "==", "active")
    .where("endDate", ">", Timestamp.fromDate(now))
    .where("endDate", "<=", Timestamp.fromMillis(now.getTime() + 3 * DAY_MS))
    .get();

  let created = 0;
  for (const subscription of subscriptions.docs) {
    const userRef = subscription.ref.parent.parent;
    const endMillis = toMillis(subscription.get("endDate"));
    if (userRef === null || endMillis === null) continue;
    const stage = premiumReminderStage(endMillis, now.getTime());
    if (stage === null) continue;

    const content = premiumReminderContent(new Date(endMillis), stage);
    try {
      await userRef.collection(Collections.NOTIFICATIONS)
        .doc(`premium_expiring_${subscription.id}_${endMillis}_${stage}`)
        .create({
          householdId: null,
          type: "system",
          title: content.title,
          message: content.message,
          inventoryItemId: null,
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      created++;
    } catch (error) {
      if ((error as {code?: number}).code !== ALREADY_EXISTS) throw error;
    }
  }
  return created;
}

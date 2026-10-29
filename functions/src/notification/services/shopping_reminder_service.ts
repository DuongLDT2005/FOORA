import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {buildShoppingSuggestions} from "../../shopping/services/purchase_frequency";
import {ShoppingService} from "../../shopping/services/shopping_service";
import {parseSettings, vnClock} from "./notification_settings";
import {
  PlannedShoppingReminder,
  planShoppingReminder,
  SHOPPING_REMINDER_TYPE,
  shoppingReminderId,
} from "./reminder_planner";

const PARALLEL_USERS = 20;
const SUGGESTIONS_IN_REMINDER = 3;
const GRPC_ALREADY_EXISTS = 6;

export interface ShoppingReminderRunResult {
  created: number;
  skipped: number;
}

/**
 * Weekly "time to go shopping" reminder (PLAN_02 §3.3). Writes a notification
 * document; the existing onNotificationNew trigger delivers the FCM push.
 */
export class ShoppingReminderService {
  static async run(now: Date): Promise<ShoppingReminderRunResult> {
    const {isoWeekday, hour, isoWeekKey} = vnClock(now);
    const snapshot = await db
      .collection(Collections.USERS)
      .where("notificationSettings.shoppingReminderEnabled", "==", true)
      .where("notificationSettings.shoppingReminderWeekday", "==", isoWeekday)
      .where("notificationSettings.reminderHour", "==", hour)
      .get();

    const users = snapshot.docs.filter((doc) => doc.get("isActive") !== false);
    const reminderByHousehold = new Map<string, Promise<PlannedShoppingReminder | null>>();
    let created = 0;
    let skipped = snapshot.size - users.length;

    for (let offset = 0; offset < users.length; offset += PARALLEL_USERS) {
      const chunk = users.slice(offset, offset + PARALLEL_USERS);
      const results = await Promise.all(chunk.map(async (doc) => {
        const settings = parseSettings(doc.get("notificationSettings"));
        const householdId = doc.get("activeHouseholdId");
        if (!settings.pushEnabled || typeof householdId !== "string" || !householdId) {
          return false;
        }

        // Members of one household share the same list, so plan it once.
        let reminderPromise = reminderByHousehold.get(householdId);
        if (!reminderPromise) {
          reminderPromise = this.planForHousehold(householdId, now);
          reminderByHousehold.set(householdId, reminderPromise);
        }
        const reminder = await reminderPromise;
        if (!reminder) {
          return false;
        }
        return this.createNotification(doc.id, householdId, isoWeekKey, reminder);
      }));
      created += results.filter(Boolean).length;
      skipped += results.filter((r) => !r).length;
    }

    return {created, skipped};
  }

  private static async planForHousehold(
    householdId: string,
    now: Date
  ): Promise<PlannedShoppingReminder | null> {
    const [pending, records] = await Promise.all([
      ShoppingService.loadPendingItems(householdId),
      ShoppingService.loadPurchaseRecords(householdId, now),
    ]);
    const suggestions = buildShoppingSuggestions({
      now,
      records,
      pendingKeys: new Set(pending.map((p) => p.key)),
    }).slice(0, SUGGESTIONS_IN_REMINDER);

    return planShoppingReminder({
      pendingNames: pending.map((p) => p.name),
      suggestionNames: suggestions.map((s) => s.name),
    });
  }

  /**
   * Uses create() with a per-week id so a retried job never sends twice.
   */
  private static async createNotification(
    userId: string,
    householdId: string,
    isoWeekKey: string,
    reminder: PlannedShoppingReminder
  ): Promise<boolean> {
    const ref = db
      .collection(Collections.USERS)
      .doc(userId)
      .collection(Collections.NOTIFICATIONS)
      .doc(shoppingReminderId(isoWeekKey));
    try {
      await ref.create({
        householdId,
        type: SHOPPING_REMINDER_TYPE,
        title: reminder.title,
        message: reminder.message,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      return true;
    } catch (error) {
      if ((error as {code?: number}).code === GRPC_ALREADY_EXISTS) {
        return false;
      }
      logger.error(`[ShoppingReminderService] Failed for user ${userId}`, error);
      return false;
    }
  }
}

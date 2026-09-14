import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {FcmService} from "../services/fcm_service";

/**
 * Firestore Trigger: Triggered whenever a new notification document is created
 * at users/{userId}/notifications/{notificationId}.
 * Automatically delivers multicast push notifications to all active user devices.
 */
export const onNotificationNew = functions
  .region(REGION)
  .firestore
  .document(
    `${Collections.USERS}/{userId}/${Collections.NOTIFICATIONS}/{notificationId}`
  )
  .onCreate(async (snapshot, context) => {
    const {userId, notificationId} = context.params;
    const data = snapshot.data();

    if (!data) {
      logger.warn(
        `[onNotificationNew] Notification ${notificationId} for user ${userId} has no data.`
      );
      return;
    }

    const title = (data.title as string) || "FOORA Thông báo";
    const message = (data.message as string) || (data.body as string) || "";
    const type = (data.type as string) || "general";
    const householdId = data.householdId as string | undefined;
    const inventoryItemId = data.inventoryItemId as string | undefined;

    logger.info(
      `[onNotificationNew] Push for user ${userId}, ` +
      `notification: ${notificationId} (Type: ${type})`
    );

    try {
      await FcmService.sendPushToUserDevices(userId, {
        notificationId,
        title,
        message,
        type,
        householdId,
        inventoryItemId,
      });
    } catch (error) {
      logger.error(
        `[onNotificationNew] Failed to deliver push for notification ${notificationId}:`,
        error
      );
    }
  });

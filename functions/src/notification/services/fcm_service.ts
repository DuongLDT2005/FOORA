import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {db, messaging} from "../../config/firebase";
import {Collections} from "../../constants/collections";

export interface PushNotificationPayload {
  title: string;
  message: string;
  type?: string;
  notificationId?: string;
  householdId?: string;
  inventoryItemId?: string;
  extraData?: Record<string, string>;
}

export interface FcmSendResult {
  totalDevices: number;
  successCount: number;
  failureCount: number;
}

export class FcmService {
  /**
   * Sends multicast push notifications to all active registered devices of a user.
   * Cleans up (sets isActive = false) any invalid/expired FCM tokens automatically.
   */
  static async sendPushToUserDevices(
    userId: string,
    payload: PushNotificationPayload
  ): Promise<FcmSendResult> {
    if (!userId) {
      logger.warn("[FcmService] Attempted to send push with empty userId");
      return {totalDevices: 0, successCount: 0, failureCount: 0};
    }

    // 1. Query active devices of the target user
    const devicesSnapshot = await db
      .collection(Collections.USERS)
      .doc(userId)
      .collection(Collections.DEVICES)
      .where("isActive", "==", true)
      .get();

    if (devicesSnapshot.empty) {
      logger.info(
        `[FcmService] No active devices found for user ${userId}. Skipping push.`
      );
      return {totalDevices: 0, successCount: 0, failureCount: 0};
    }

    const deviceDocs = devicesSnapshot.docs;
    const tokens: string[] = [];
    const docIds: string[] = [];

    for (const doc of deviceDocs) {
      const data = doc.data();
      const token = data.fcmToken as string | undefined;
      if (token && typeof token === "string" && token.trim().length > 0) {
        tokens.push(token.trim());
        docIds.push(doc.id);
      }
    }

    if (tokens.length === 0) {
      logger.info(
        `[FcmService] Active devices found for user ${userId}, but all tokens are empty.`
      );
      return {totalDevices: 0, successCount: 0, failureCount: 0};
    }

    // 2. Prepare FCM Multicast Message Payload
    const dataPayload: Record<string, string> = {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      notificationId: payload.notificationId || "",
      type: payload.type || "general",
      ...(payload.householdId ? {householdId: payload.householdId} : {}),
      ...(payload.inventoryItemId ?
        {inventoryItemId: payload.inventoryItemId} :
        {}),
      ...(payload.extraData || {}),
    };

    const multicastMessage: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: payload.title,
        body: payload.message,
      },
      data: dataPayload,
      android: {
        priority: "high",
        notification: {
          channelId: "foora_notifications",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // 3. Dispatch multicast push
    try {
      const response = await messaging.sendEachForMulticast(multicastMessage);
      logger.info(
        `[FcmService] Sent push to user ${userId}: ` +
        `${response.successCount}/${tokens.length} successful.`
      );

      // 4. Cleanup dead / unregistered tokens
      if (response.failureCount > 0) {
        const batch = db.batch();
        let cleanupCount = 0;

        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const errorCode = resp.error.code;
            const docId = docIds[idx];

            if (
              errorCode === "messaging/registration-token-not-registered" ||
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/invalid-argument"
            ) {
              const deviceRef = db
                .collection(Collections.USERS)
                .doc(userId)
                .collection(Collections.DEVICES)
                .doc(docId);

              batch.update(deviceRef, {
                isActive: false,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              cleanupCount++;
            }
          }
        });

        if (cleanupCount > 0) {
          await batch.commit();
          logger.info(
            `[FcmService] Cleaned up ${cleanupCount} dead tokens for user ${userId}.`
          );
        }
      }

      return {
        totalDevices: tokens.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (error) {
      logger.error(
        `[FcmService] Failed to send multicast message to user ${userId}:`,
        error
      );
      throw error;
    }
  }
}

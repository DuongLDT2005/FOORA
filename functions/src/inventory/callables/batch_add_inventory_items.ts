import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {FieldValue} from "firebase-admin/firestore";
import {REGION, db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {normalizeFoodName} from "../../utils/string";
import {
  InventoryService,
  AddInventoryItemInput,
} from "../services/inventory_service";

interface BatchAddPayload {
  householdId: string;
  items: AddInventoryItemInput[];
  receiptId?: string;
}

interface BatchAddResult {
  addedCount: number;
  itemIds: string[];
}

/**
 * Callable Function: batchAddInventoryItems
 * Adds multiple food items simultaneously into household inventory
 * with atomic limit check and expiration calculations.
 * Also archives confirmed items into users/{userId}/receipts/{receiptId}/items.
 */
export const batchAddInventoryItems = onCall<Partial<BatchAddPayload>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<BatchAddResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, items, receiptId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      if (!items || !Array.isArray(items) || items.length === 0) {
        throwInvalidArgument("Danh sách thực phẩm thêm vào (items) không được rỗng.");
      }

      // Validate each item basic fields
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        if (!item.name || typeof item.name !== "string" || !item.name.trim()) {
          throwInvalidArgument(`Món thứ ${i + 1} có tên không hợp lệ.`);
        }
        if (!item.categoryId) {
          throwInvalidArgument(`Món "${item.name}" thiếu categoryId.`);
        }
        if (typeof item.quantity !== "number" || item.quantity <= 0) {
          item.quantity = 1;
        }
        if (!item.unit || typeof item.unit !== "string") {
          item.unit = "quả";
        }
        if (!item.storageLocationId) {
          item.storageLocationId = "fridge";
        }
      }

      logger.info(
        `[batchAddInventoryItems] User ${user.uid} adding ` +
        `${items.length} items to household ${householdId}` +
        (receiptId ? ` from receipt ${receiptId}` : "")
      );

      // 1. Add batch to household inventory
      const result = await InventoryService.addBatchInventoryItemsWithLimitCheck(
        user.uid,
        user.membershipId,
        householdId,
        items
      );

      // 2. If this came from a receipt scan, update receipt & save confirmed receipt_items
      if (receiptId && typeof receiptId === "string") {
        try {
          const receiptRef = db
            .collection(Collections.USERS)
            .doc(user.uid)
            .collection(Collections.RECEIPTS)
            .doc(receiptId);

          const batch = db.batch();
          const serverTimestamp = FieldValue.serverTimestamp();
          batch.set(
            receiptRef,
            {
              receiptId,
              householdId,
              status: "completed",
              confirmedItemsCount: items.length,
              updatedAt: serverTimestamp,
            },
            {merge: true}
          );

          // Write into subcollection users/{userId}/receipts/{receiptId}/items
          const itemsCollection = receiptRef.collection(Collections.RECEIPT_ITEMS);
          for (let i = 0; i < items.length; i++) {
            const item = items[i];
            const itemDocRef = itemsCollection.doc();
            batch.set(itemDocRef, {
              receiptItemId: itemDocRef.id,
              inventoryItemId: result.itemIds[i] || null,
              rawName: item.name,
              normalizedName: normalizeFoodName(item.name),
              foodId: item.foodId || null,
              categoryId: item.categoryId,
              quantity: item.quantity,
              unit: item.unit,
              storageLocationId: item.storageLocationId,
              confidence: 1.0, // Confirmed by user
              createdAt: serverTimestamp,
            });
          }

          await batch.commit();
          logger.info(
            `[batchAddInventoryItems] Successfully archived receipt ${receiptId} ` +
            `with ${items.length} items in users/${user.uid}/receipts/${receiptId}`
          );
        } catch (receiptErr) {
          logger.error(
            `[batchAddInventoryItems] Failed to archive receipt ${receiptId}:`,
            receiptErr
          );
        }
      }

      return {
        success: true,
        data: {
          addedCount: result.itemIds.length,
          itemIds: result.itemIds,
        },
        message: `Đã thêm thành công ${result.itemIds.length} món vào tủ lạnh!`,
      };
    } catch (error) {
      handleFunctionError(error, "batchAddInventoryItems");
    }
  }
);

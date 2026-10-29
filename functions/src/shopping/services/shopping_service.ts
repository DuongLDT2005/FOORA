import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {InventoryService} from "../../inventory/services/inventory_service";
import {verifyHouseholdAccess} from "../../utils/auth";
import {
  throwFailedPrecondition,
  throwInvalidArgument,
  throwNotFound,
} from "../../utils/errors";
import {normalizeFoodName} from "../../utils/string";
import {
  buildShoppingSuggestions,
  LOOKBACK_DAYS,
  PurchaseRecord,
  PurchaseStatus,
  purchaseKey,
  ShoppingSuggestion,
} from "./purchase_frequency";
import {ImportShoppingItemInput} from "./shopping_validation";

const MAX_HISTORY_RECORDS = 1000;
const PURCHASE_STATUSES: readonly PurchaseStatus[] = ["active", "consumed", "discarded"];

/**
 * Pending shopping items of a household, across all of its lists.
 */
export interface PendingShoppingItem {
  key: string;
  name: string;
}

export class ShoppingService {
  /**
   * Deletes a shopping list and all of its items. Clients cannot delete lists
   * directly because Firestore does not cascade subcollection deletes.
   */
  static async deleteShoppingList(
    uid: string,
    householdId: string,
    shoppingListId: string
  ): Promise<void> {
    await verifyHouseholdAccess(uid, householdId);

    const listRef = this.listRef(householdId, shoppingListId);
    const listDoc = await listRef.get();
    if (!listDoc.exists) {
      throwNotFound("Danh sách mua sắm không tồn tại.");
    }

    await db.recursiveDelete(listRef);
  }

  /**
   * Moves purchased shopping items into the household inventory in a single
   * transaction (all-or-nothing), enforcing the owner's foodLimit.
   */
  static async importShoppingItemsToInventory(
    uid: string,
    householdId: string,
    shoppingListId: string,
    itemsToImport: ImportShoppingItemInput[]
  ): Promise<{addedCount: number; itemIds: string[]}> {
    await verifyHouseholdAccess(uid, householdId);
    await this.assertCategoriesExist(itemsToImport.map((i) => i.categoryId));
    const membershipId = await InventoryService.resolveHouseholdMembershipId(householdId);

    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const listRef = this.listRef(householdId, shoppingListId);
    const itemRefs = itemsToImport.map((i) =>
      listRef.collection(Collections.SHOPPING_ITEMS).doc(i.shoppingItemId)
    );

    // Expiry only depends on the request, so it is computed before the transaction.
    const preCheckDocs = await db.getAll(...itemRefs);
    const expirationDates = await Promise.all(
      itemsToImport.map((req, idx) => {
        const foodId = (preCheckDocs[idx].get("foodId") as string | null) || null;
        return InventoryService.calculateExpirationDate(
          foodId,
          req.categoryId,
          req.storageLocationId,
          req.purchaseDate
        );
      })
    );

    return db.runTransaction(async (transaction) => {
      const householdDoc = await transaction.get(householdRef);
      if (!householdDoc.exists) {
        throwNotFound("Hộ gia đình không tồn tại.");
      }
      const listDoc = await transaction.get(listRef);
      if (!listDoc.exists) {
        throwNotFound("Danh sách mua sắm không tồn tại.");
      }

      // Read the items inside the transaction so two members importing at the
      // same time cannot both create inventory batches.
      const itemDocs = await transaction.getAll(...itemRefs);
      const alreadyImported = itemDocs.filter((d) => d.get("isAddedToInventory") === true);
      if (alreadyImported.length === itemDocs.length) {
        return {
          addedCount: 0,
          itemIds: itemDocs.map((d) => d.get("inventoryItemId") as string),
        };
      }
      if (alreadyImported.length > 0) {
        throwFailedPrecondition(
          "Một số món đã được người khác nhập kho. Vui lòng tải lại danh sách."
        );
      }

      const prepared = itemDocs.map((doc, idx) => {
        if (!doc.exists) {
          throwNotFound("Món cần mua không còn tồn tại.");
        }
        const data = doc.data()!;
        if (data.isPurchased !== true) {
          throwFailedPrecondition(`Món "${data.name}" chưa được đánh dấu là đã mua.`);
        }
        const req = itemsToImport[idx];
        const name = typeof data.name === "string" ? data.name.trim() : "";
        const unit = typeof data.unit === "string" ? data.unit.trim() : "";
        if (!name || !unit) {
          throwInvalidArgument("Món cần mua thiếu tên hoặc đơn vị.");
        }
        return {
          input: {
            foodId: (data.foodId as string | null) || null,
            name,
            categoryId: req.categoryId,
            storageLocationId: req.storageLocationId,
            unit,
            source: "manual",
          },
          normalizedName: (data.normalizedName as string) || normalizeFoodName(name),
          actualQuantity: req.actualQuantity,
          purchaseDate: req.purchaseDate,
          finalExpirationDate: expirationDates[idx],
          photoUrl: (data.photoUrl as string | null) || null,
        };
      });

      const inventoryIds = await InventoryService.executeBatchAddInTransaction(
        transaction,
        householdRef,
        householdDoc.data()!,
        membershipId,
        prepared
      );

      const serverTimestamp = FieldValue.serverTimestamp();
      itemRefs.forEach((ref, idx) => {
        transaction.update(ref, {
          isAddedToInventory: true,
          inventoryItemId: inventoryIds[idx],
          quantity: itemsToImport[idx].actualQuantity,
          addedToInventoryAt: serverTimestamp,
          updatedAt: serverTimestamp,
        });
      });

      return {addedCount: inventoryIds.length, itemIds: inventoryIds};
    });
  }

  /**
   * "Frequently bought" suggestions for a household (PLAN_01 §4.2). Read-only.
   */
  static async getSuggestions(
    uid: string,
    householdId: string,
    now: Date = new Date()
  ): Promise<ShoppingSuggestion[]> {
    await verifyHouseholdAccess(uid, householdId);
    const [records, pending] = await Promise.all([
      this.loadPurchaseRecords(householdId, now),
      this.loadPendingItems(householdId),
    ]);
    return buildShoppingSuggestions({
      now,
      records,
      pendingKeys: new Set(pending.map((p) => p.key)),
    });
  }

  /**
   * Inventory batches bought within the lookback window, as algorithm input.
   */
  static async loadPurchaseRecords(
    householdId: string,
    now: Date
  ): Promise<PurchaseRecord[]> {
    const cutoff = new Date(now.getTime() - LOOKBACK_DAYS * 86400000);
    const snapshot = await db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .collection(Collections.INVENTORY_ITEMS)
      .where("purchaseDate", ">=", Timestamp.fromDate(cutoff))
      .limit(MAX_HISTORY_RECORDS)
      .get();

    const records: PurchaseRecord[] = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const purchaseDate = data.purchaseDate instanceof Timestamp ?
        data.purchaseDate.toDate() :
        null;
      const status = data.status as PurchaseStatus;
      const name = typeof data.name === "string" ? data.name.trim() : "";
      const key = purchaseKey(
        data.foodId,
        data.normalizedName || normalizeFoodName(name)
      );
      if (!purchaseDate || !key || !name || !PURCHASE_STATUSES.includes(status)) {
        continue;
      }
      records.push({
        key,
        name,
        quantity: Number(data.initialQuantity ?? data.quantity) || 1,
        unit: typeof data.unit === "string" ? data.unit : "",
        categoryId: typeof data.categoryId === "string" ? data.categoryId : "",
        foodId: typeof data.foodId === "string" ? data.foodId : null,
        purchaseDate,
        status,
        remainingPercentage: Number(data.remainingPercentage) || 0,
      });
    }
    return records;
  }

  /**
   * Items still to buy in every shopping list of the household, oldest first.
   */
  static async loadPendingItems(householdId: string): Promise<PendingShoppingItem[]> {
    const lists = await db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .collection(Collections.SHOPPING_LISTS)
      .get();

    const snapshots = await Promise.all(
      lists.docs.map((list) =>
        list.ref
          .collection(Collections.SHOPPING_ITEMS)
          .where("isPurchased", "==", false)
          .get()
      )
    );

    return snapshots
      .flatMap((s) => s.docs)
      .sort((a, b) => millis(a.get("createdAt")) - millis(b.get("createdAt")))
      .map((doc) => {
        const name = typeof doc.get("name") === "string" ? doc.get("name") as string : "";
        return {
          key: purchaseKey(doc.get("foodId"), doc.get("normalizedName") || normalizeFoodName(name)),
          name,
        };
      })
      .filter((item) => item.key && item.name);
  }

  private static listRef(householdId: string, shoppingListId: string) {
    return db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .collection(Collections.SHOPPING_LISTS)
      .doc(shoppingListId);
  }

  private static async assertCategoriesExist(categoryIds: string[]): Promise<void> {
    const unique = [...new Set(categoryIds)];
    const docs = await db.getAll(
      ...unique.map((id) => db.collection(Collections.FOOD_CATEGORIES).doc(id))
    );
    if (docs.some((doc) => !doc.exists)) {
      throwInvalidArgument("Danh mục thực phẩm không tồn tại.");
    }
  }
}

function millis(value: unknown): number {
  return value instanceof Timestamp ? value.toMillis() : 0;
}

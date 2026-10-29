import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {FieldValue} from "firebase-admin/firestore";
import {
  throwNotFound,
  throwPermissionDenied,
  throwFailedPrecondition,
  throwInvalidArgument,
} from "../../utils/errors";
import {normalizeFoodName} from "../../utils/string";
import {InventoryService} from "../../inventory/services/inventory_service";

export interface AddShoppingItemInput {
  householdId: string;
  shoppingListId: string;
  name: string;
  categoryId: string;
  quantity: number;
  unit: string;
  foodId?: string | null;
  note?: string | null;
  photoUrl?: string | null;
  source?: string;
  mergeConfirmed?: boolean;
}

export interface AddShoppingItemsBatchInput {
  householdId: string;
  shoppingListId: string;
  items: Array<{
    name: string;
    categoryId: string;
    quantity: number;
    unit: string;
    foodId?: string | null;
    note?: string | null;
    photoUrl?: string | null;
    inventoryRefId?: string | null;
    source?: string;
  }>;
}

export interface ImportShoppingItemInput {
  shoppingItemId: string;
  storageLocationId: "fridge" | "freezer";
  categoryId: string;
  actualQuantity: number;
  purchaseDate?: string;
}

export class ShoppingService {
  /**
   * Helper to verify if caller is an active member or owner of the household.
   */
  static async verifyHouseholdMember(
    householdId: string,
    uid: string
  ): Promise<FirebaseFirestore.DocumentData> {
    const householdDoc = await db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .get();

    if (!householdDoc.exists) {
      throwNotFound("Hộ gia đình không tồn tại.");
    }

    const data = householdDoc.data()!;
    const members: string[] = data.members || [];
    if (!members.includes(uid) && data.ownerId !== uid) {
      throwPermissionDenied("Bạn không có quyền truy cập vào gia đình này.");
    }

    return data;
  }

  /**
   * Add a shopping item with atomic counter increment or duplicate merge.
   */
  static async addShoppingItem(
    uid: string,
    input: AddShoppingItemInput
  ): Promise<{itemId: string; merged: boolean}> {
    await this.verifyHouseholdMember(input.householdId, uid);

    const listRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(input.householdId)
      .collection(Collections.SHOPPING_LISTS)
      .doc(input.shoppingListId);

    const normalized = normalizeFoodName(input.name);
    const serverTimestamp = FieldValue.serverTimestamp();

    return await db.runTransaction(async (transaction) => {
      const listDoc = await transaction.get(listRef);
      if (!listDoc.exists) {
        throwNotFound("Danh sách mua sắm không tồn tại.");
      }

      const listData = listDoc.data()!;
      if (listData.status !== "active") {
        throwFailedPrecondition("Danh sách mua sắm đang ở trạng thái không hoạt động.");
      }

      let mergedItemId: string | null = null;

      // In-transaction stale data re-check if merge was confirmed by user
      if (input.mergeConfirmed) {
        const querySnapshot = await transaction.get(
          listRef
            .collection(Collections.SHOPPING_ITEMS)
            .where("isPurchased", "==", false)
        );

        for (const doc of querySnapshot.docs) {
          const item = doc.data();
          if (
            item.normalizedName === normalized &&
            item.unit?.trim().toLowerCase() === input.unit.trim().toLowerCase()
          ) {
            mergedItemId = doc.id;
            const updatedQuantity = (Number(item.quantity) || 0) + input.quantity;
            let mergedNote = item.note || "";
            if (input.note && input.note.trim()) {
              mergedNote = mergedNote ?
                `${mergedNote}; ${input.note.trim()}` :
                input.note.trim();
            }

            transaction.update(doc.ref, {
              quantity: updatedQuantity,
              note: mergedNote ? mergedNote.substring(0, 200) : null,
              updatedAt: serverTimestamp,
            });

            // Keep totalItemsCount unchanged when merging into existing item
            transaction.update(listRef, {
              updatedAt: serverTimestamp,
            });
            break;
          }
        }
      }

      if (mergedItemId) {
        return {itemId: mergedItemId, merged: true};
      }

      // Not merged: Create a new item document and increment totalItemsCount by 1
      const itemRef = listRef.collection(Collections.SHOPPING_ITEMS).doc();
      transaction.set(itemRef, {
        name: input.name.trim(),
        normalizedName: normalized,
        foodId: input.foodId || null,
        categoryId: input.categoryId || "other",
        quantity: input.quantity,
        unit: input.unit.trim(),
        note: input.note ? input.note.trim().substring(0, 200) : null,
        photoUrl: input.photoUrl || null,
        isPurchased: false,
        purchasedBy: null,
        purchasedAt: null,
        isAddedToInventory: false,
        inventoryItemId: null,
        addedToInventoryAt: null,
        source: input.source || "manual",
        inventoryRefId: null,
        addedBy: uid,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });

      const currentTotal = (listData.totalItemsCount as number) || 0;
      transaction.update(listRef, {
        totalItemsCount: currentTotal + 1,
        updatedAt: serverTimestamp,
      });

      return {itemId: itemRef.id, merged: false};
    });
  }

  /**
   * Add multiple shopping items at once (e.g. from Inventory).
   */
  static async addShoppingItemsBatch(
    uid: string,
    input: AddShoppingItemsBatchInput
  ): Promise<{count: number}> {
    if (!input.items || input.items.length === 0) {
      return {count: 0};
    }

    await this.verifyHouseholdMember(input.householdId, uid);

    const listRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(input.householdId)
      .collection(Collections.SHOPPING_LISTS)
      .doc(input.shoppingListId);

    const serverTimestamp = FieldValue.serverTimestamp();

    return await db.runTransaction(async (transaction) => {
      const listDoc = await transaction.get(listRef);
      if (!listDoc.exists) {
        throwNotFound("Danh sách mua sắm không tồn tại.");
      }

      const listData = listDoc.data()!;
      if (listData.status !== "active") {
        throwFailedPrecondition("Danh sách mua sắm không ở trạng thái hoạt động.");
      }

      for (const item of input.items) {
        const itemRef = listRef.collection(Collections.SHOPPING_ITEMS).doc();
        transaction.set(itemRef, {
          name: item.name.trim(),
          normalizedName: normalizeFoodName(item.name),
          foodId: item.foodId || null,
          categoryId: item.categoryId || "other",
          quantity: item.quantity,
          unit: item.unit.trim(),
          note: item.note ? item.note.trim().substring(0, 200) : null,
          photoUrl: item.photoUrl || null,
          isPurchased: false,
          purchasedBy: null,
          purchasedAt: null,
          isAddedToInventory: false,
          inventoryItemId: null,
          addedToInventoryAt: null,
          source: item.source || "inventory",
          inventoryRefId: item.inventoryRefId || null,
          addedBy: uid,
          createdAt: serverTimestamp,
          updatedAt: serverTimestamp,
        });
      }

      const currentTotal = (listData.totalItemsCount as number) || 0;
      transaction.update(listRef, {
        totalItemsCount: currentTotal + input.items.length,
        updatedAt: serverTimestamp,
      });

      return {count: input.items.length};
    });
  }

  /**
   * Delete a shopping item with atomic counter decrement.
   */
  static async deleteShoppingItem(
    uid: string,
    householdId: string,
    shoppingListId: string,
    itemId: string
  ): Promise<{success: boolean}> {
    await this.verifyHouseholdMember(householdId, uid);

    const listRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .collection(Collections.SHOPPING_LISTS)
      .doc(shoppingListId);

    const itemRef = listRef.collection(Collections.SHOPPING_ITEMS).doc(itemId);
    const serverTimestamp = FieldValue.serverTimestamp();

    return await db.runTransaction(async (transaction) => {
      const listDoc = await transaction.get(listRef);
      if (!listDoc.exists) {
        throwNotFound("Danh sách mua sắm không tồn tại.");
      }

      const listData = listDoc.data()!;
      if (listData.status === "deleting") {
        throwFailedPrecondition("Danh sách đang trong tiến trình xóa.");
      }

      const itemDoc = await transaction.get(itemRef);
      if (!itemDoc.exists) {
        throwNotFound("Món cần mua không tồn tại.");
      }

      const itemData = itemDoc.data()!;
      transaction.delete(itemRef);

      const currentTotal = (listData.totalItemsCount as number) || 0;
      const currentPurchased = (listData.purchasedItemsCount as number) || 0;

      const newTotal = Math.max(0, currentTotal - 1);
      const newPurchased = itemData.isPurchased ?
        Math.max(0, currentPurchased - 1) :
        currentPurchased;

      transaction.update(listRef, {
        totalItemsCount: newTotal,
        purchasedItemsCount: newPurchased,
        updatedAt: serverTimestamp,
      });

      return {success: true};
    });
  }

  /**
   * Toggle purchased status with atomic counter update and idempotency protection.
   */
  static async toggleShoppingItemPurchased(
    uid: string,
    householdId: string,
    shoppingListId: string,
    itemId: string,
    targetStatus: boolean
  ): Promise<{success: boolean; isPurchased: boolean}> {
    await this.verifyHouseholdMember(householdId, uid);

    const listRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .collection(Collections.SHOPPING_LISTS)
      .doc(shoppingListId);

    const itemRef = listRef.collection(Collections.SHOPPING_ITEMS).doc(itemId);
    const serverTimestamp = FieldValue.serverTimestamp();

    return await db.runTransaction(async (transaction) => {
      const listDoc = await transaction.get(listRef);
      if (!listDoc.exists) {
        throwNotFound("Danh sách mua sắm không tồn tại.");
      }

      const listData = listDoc.data()!;
      if (listData.status !== "active") {
        throwFailedPrecondition("Chỉ có thể đánh dấu đã mua khi danh sách đang mở (active).");
      }

      const itemDoc = await transaction.get(itemRef);
      if (!itemDoc.exists) {
        throwNotFound("Món cần mua không tồn tại.");
      }

      const itemData = itemDoc.data()!;

      // Protection: Cannot un-tick an item that has already been added to inventory
      if (itemData.isAddedToInventory && !targetStatus) {
        throwFailedPrecondition("Món đã nhập vào tủ lạnh không thể chuyển về chưa mua.");
      }

      // Idempotency: If already in target status, return NO-OP
      if (itemData.isPurchased === targetStatus) {
        return {success: true, isPurchased: targetStatus};
      }

      transaction.update(itemRef, {
        isPurchased: targetStatus,
        purchasedBy: targetStatus ? uid : null,
        purchasedAt: targetStatus ? serverTimestamp : null,
        updatedAt: serverTimestamp,
      });

      const currentPurchased = (listData.purchasedItemsCount as number) || 0;
      const totalCount = (listData.totalItemsCount as number) || 0;
      const delta = targetStatus ? 1 : -1;
      const newPurchased = Math.max(0, Math.min(totalCount, currentPurchased + delta));

      transaction.update(listRef, {
        purchasedItemsCount: newPurchased,
        updatedAt: serverTimestamp,
      });

      return {success: true, isPurchased: targetStatus};
    });
  }

  /**
   * Safe list deletion: Sets status = 'deleting' and recursively cleans up subcollections.
   */
  static async deleteShoppingList(
    uid: string,
    householdId: string,
    shoppingListId: string
  ): Promise<{success: boolean}> {
    await this.verifyHouseholdMember(householdId, uid);

    const listRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId)
      .collection(Collections.SHOPPING_LISTS)
      .doc(shoppingListId);

    // Step 1: Set status = 'deleting' to block all concurrent writes
    await db.runTransaction(async (transaction) => {
      const listDoc = await transaction.get(listRef);
      if (!listDoc.exists) {
        throwNotFound("Danh sách mua sắm không tồn tại.");
      }

      transaction.update(listRef, {
        status: "deleting",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    // Step 2: Recursively delete subcollections and the parent document
    await db.recursiveDelete(listRef);

    return {success: true};
  }

  /**
   * Batch import purchased shopping items into household inventory (All-or-Nothing).
   */
  static async importShoppingItemsToInventory(
    uid: string,
    householdId: string,
    shoppingListId: string,
    itemsToImport: ImportShoppingItemInput[]
  ): Promise<{success: boolean; addedCount: number; itemIds: string[]}> {
    if (!itemsToImport || itemsToImport.length === 0) {
      throwInvalidArgument("Danh sách món cần nhập kho không được để trống.");
    }

    await this.verifyHouseholdMember(householdId, uid);
    const membershipId = await InventoryService.resolveHouseholdMembershipId(householdId);

    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
    const listRef = householdRef
      .collection(Collections.SHOPPING_LISTS)
      .doc(shoppingListId);

    // 1. Verify parent list state
    const listDoc = await listRef.get();
    if (!listDoc.exists) {
      throwNotFound("Danh sách mua sắm không tồn tại.");
    }

    const listData = listDoc.data()!;
    if (listData.status === "deleting") {
      throwFailedPrecondition("Danh sách đang trong tiến trình xóa.");
    }

    // 2. Fetch and authenticate shopping items from DB
    const itemRefs = itemsToImport.map((i) =>
      listRef.collection(Collections.SHOPPING_ITEMS).doc(i.shoppingItemId)
    );
    const itemDocs = await db.getAll(...itemRefs);

    // Pre-flight checks
    let allAlreadyImported = true;
    for (let idx = 0; idx < itemDocs.length; idx++) {
      const doc = itemDocs[idx];
      const req = itemsToImport[idx];

      if (!doc.exists) {
        throwNotFound(`Không tìm thấy món cần mua với ID ${req.shoppingItemId}.`);
      }

      const data = doc.data()!;
      if (!data.isAddedToInventory) {
        allAlreadyImported = false;
      }

      if (!data.isPurchased) {
        throwFailedPrecondition(`Món "${data.name}" chưa được đánh dấu là đã mua.`);
      }

      if (req.actualQuantity <= 0) {
        throwInvalidArgument(`Số lượng thực mua của món "${data.name}" phải lớn hơn 0.`);
      }

      if (!req.categoryId || req.categoryId === "other") {
        throwInvalidArgument(`Món "${data.name}" bắt buộc phải chọn danh mục cụ thể (không được để "Khác").`);
      }

      if (!["fridge", "freezer"].includes(req.storageLocationId)) {
        throwInvalidArgument(`Vị trí bảo quản của món "${data.name}" không hợp lệ.`);
      }
    }

    // Network retry / Idempotency handling
    if (allAlreadyImported) {
      const existingInventoryIds = itemDocs.map((d) => d.data()!.inventoryItemId as string);
      return {
        success: true,
        addedCount: 0,
        itemIds: existingInventoryIds,
      };
    }

    // Check if partial items were imported
    const hasSomeImported = itemDocs.some((d) => d.data()!.isAddedToInventory);
    if (hasSomeImported) {
      throwFailedPrecondition("Một số món đã được nhập kho trước đó. Vui lòng làm mới danh sách.");
    }

    // 3. Pre-calculate expiration dates for all items
    const preparedItems = await Promise.all(
      itemsToImport.map(async (req, idx) => {
        const itemData = itemDocs[idx].data()!;
        const purchaseDate = req.purchaseDate ? new Date(req.purchaseDate) : new Date();

        const finalExp = await InventoryService.calculateExpirationDate(
          itemData.foodId || null,
          req.categoryId,
          req.storageLocationId,
          purchaseDate
        );

        return {
          req,
          itemRef: itemRefs[idx],
          itemData,
          input: {
            foodId: itemData.foodId || null,
            name: itemData.name,
            categoryId: req.categoryId,
            storageLocationId: req.storageLocationId,
            unit: itemData.unit,
            source: "manual",
          },
          normalizedName: itemData.normalizedName || normalizeFoodName(itemData.name),
          actualQuantity: req.actualQuantity,
          purchaseDate,
          finalExpirationDate: finalExp,
          photoUrl: itemData.photoUrl || null,
        };
      })
    );

    // 4. Atomic Transaction: Write to inventory_items and update shopping_items (All-or-Nothing)
    const createdItemIds = await db.runTransaction(async (transaction) => {
      // Re-fetch household data in transaction
      const currentHouseholdDoc = await transaction.get(householdRef);
      if (!currentHouseholdDoc.exists) {
        throwNotFound("Hộ gia đình không tồn tại.");
      }

      // Add to inventory
      const newInventoryIds = await InventoryService.executeBatchAddInTransaction(
        transaction,
        householdRef,
        currentHouseholdDoc.data()!,
        membershipId,
        preparedItems.map((p) => ({
          input: p.input,
          normalizedName: p.normalizedName,
          actualQuantity: p.actualQuantity,
          purchaseDate: p.purchaseDate,
          finalExpirationDate: p.finalExpirationDate,
          photoUrl: p.photoUrl,
        }))
      );

      // Update each shopping item in transaction
      const serverTimestamp = FieldValue.serverTimestamp();
      for (let i = 0; i < preparedItems.length; i++) {
        const p = preparedItems[i];
        const newInvId = newInventoryIds[i];

        transaction.update(p.itemRef, {
          isAddedToInventory: true,
          inventoryItemId: newInvId,
          quantity: p.actualQuantity,
          addedToInventoryAt: serverTimestamp,
          updatedAt: serverTimestamp,
        });
      }

      return newInventoryIds;
    });

    return {
      success: true,
      addedCount: createdItemIds.length,
      itemIds: createdItemIds,
    };
  }
}

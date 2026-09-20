import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {
  throwNotFound,
  throwPermissionDenied,
  throwResourceExhausted,
} from "../../utils/errors";
import {normalizeFoodName} from "../../utils/string";

export interface AddInventoryItemInput {
  householdId: string;
  name: string;
  foodId?: string | null;
  categoryId: string;
  quantity: number;
  unit: string;
  storageLocationId: string;
  purchaseDate: string | number | Date;
  expirationDate?: string | number | Date | null;
  photoUrl?: string | null;
  source?: "manual" | "receipt_scan";
}

export class InventoryService {
  /**
   * Calculates estimated expiration date using:
   * 1. Exact rule from `shelf_life_rules` matching foodId + storageLocationId
   * 2. Fallback rule from `food_categories` defaultShelfLife matching
   *    categoryId + storageLocationId
   * 3. Fallback default: 3 days (fridge) / 30 days (freezer)
   */
  static async calculateExpirationDate(
    foodId: string | null | undefined,
    categoryId: string,
    storageLocationId: string,
    purchaseDate: Date
  ): Promise<Date> {
    let durationValue: number | null = null;
    let durationUnit: string | null = null;

    // 1. Try exact match in shelf_life_rules if foodId exists
    if (foodId) {
      const ruleSnapshot = await db
        .collection(Collections.SHELF_LIFE_RULES)
        .where("foodId", "==", foodId)
        .where("storageLocationId", "==", storageLocationId)
        .where("isActive", "==", true)
        .limit(1)
        .get();

      if (!ruleSnapshot.empty) {
        const ruleData = ruleSnapshot.docs[0].data();
        durationValue = ruleData.maxValue ?? ruleData.minValue ?? null;
        durationUnit = ruleData.unit ?? null;
      }
    }

    // 2. Fallback to category defaultShelfLife
    if (durationValue === null && categoryId) {
      const catDoc = await db
        .collection(Collections.FOOD_CATEGORIES)
        .doc(categoryId)
        .get();

      if (catDoc.exists) {
        const defaultShelfLife = catDoc.data()?.defaultShelfLife;
        const locRule = defaultShelfLife?.[storageLocationId];
        if (locRule) {
          durationValue = locRule.maxValue ?? locRule.minValue ?? null;
          durationUnit = locRule.unit ?? null;
        }
      }
    }

    // 3. Fallback default if still not determined
    if (durationValue === null || !durationUnit) {
      durationValue = storageLocationId === "freezer" ? 30 : 3;
      durationUnit = "days";
    }

    // Calculate future date based on unit
    const exp = new Date(purchaseDate.getTime());
    switch (durationUnit) {
    case "days":
      exp.setDate(exp.getDate() + durationValue);
      break;
    case "weeks":
      exp.setDate(exp.getDate() + durationValue * 7);
      break;
    case "months":
      exp.setMonth(exp.getMonth() + durationValue);
      break;
    case "years":
      exp.setFullYear(exp.getFullYear() + durationValue);
      break;
    default:
      exp.setDate(exp.getDate() + durationValue);
    }

    return exp;
  }

  /**
   * Atomic Firestore Transaction:
   * 1. Validates caller's membership foodLimit against current household activeItemCount
   * 2. Creates the inventory item document with status 'active' and auto normalizedName
   * 3. Atomically increments household activeItemCount by 1
   */
  static async addInventoryItemWithLimitCheck(
    uid: string,
    membershipId: string,
    input: AddInventoryItemInput
  ): Promise<{itemId: string; expirationDate: Date}> {
    const householdRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(input.householdId);
    const itemRef = householdRef.collection(Collections.INVENTORY_ITEMS).doc();

    // 1. Resolve membership food limit
    let foodLimit: number | null = null;
    const membershipDoc = await db
      .collection(Collections.MEMBERSHIPS)
      .doc(membershipId)
      .get();

    if (membershipDoc.exists) {
      foodLimit = membershipDoc.data()?.foodLimit ?? null;
    } else if (membershipId === "free") {
      foodLimit = 30; // Hard fallback for free tier
    }

    // 2. Parse purchase and expiration dates
    const purchaseDate = input.purchaseDate ?
      new Date(input.purchaseDate) :
      new Date();

    let finalExpirationDate: Date;
    if (input.expirationDate) {
      finalExpirationDate = new Date(input.expirationDate);
    } else {
      finalExpirationDate = await this.calculateExpirationDate(
        input.foodId,
        input.categoryId,
        input.storageLocationId,
        purchaseDate
      );
    }

    let resolvedPhotoUrl = input.photoUrl || null;
    if (!resolvedPhotoUrl && input.foodId) {
      try {
        const foodDoc = await db.collection(Collections.FOODS).doc(input.foodId).get();
        if (foodDoc.exists) {
          resolvedPhotoUrl = (foodDoc.data()?.photoUrl as string) || null;
        }
      } catch {
        // Non-fatal, continue with null
      }
    }

    const normalized = normalizeFoodName(input.name);
    const serverTimestamp = FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
      const householdDoc = await transaction.get(householdRef);
      if (!householdDoc.exists) {
        throwNotFound("Hộ gia đình không tồn tại.");
      }

      const householdData = householdDoc.data()!;
      const members: string[] = householdData.members || [];
      if (!members.includes(uid) && householdData.ownerId !== uid) {
        throwPermissionDenied("Bạn không có quyền thêm món vào gia đình này.");
      }

      const currentActiveCount = (householdData.activeItemCount as number) || 0;

      // Check foodLimit restriction for Free accounts
      if (foodLimit !== null && currentActiveCount >= foodLimit) {
        throwResourceExhausted(
          `Gói tài khoản của bạn đã đạt giới hạn tối đa (${foodLimit} món đang lưu trữ). ` +
          "Vui lòng tiêu thụ thực phẩm hoặc nâng cấp lên gói Premium để không giới hạn!"
        );
      }

      // Set inventory item data
      transaction.set(itemRef, {
        foodId: input.foodId || null,
        name: input.name.trim(),
        normalizedName: normalized,
        categoryId: input.categoryId,
        quantity: input.quantity,
        unit: input.unit.trim(),
        remainingPercentage: 100,
        storageLocationId: input.storageLocationId,
        purchaseDate: Timestamp.fromDate(purchaseDate),
        expirationDate: Timestamp.fromDate(finalExpirationDate),
        source: input.source || "manual",
        status: "active",
        photoUrl: resolvedPhotoUrl,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });

      // Atomically increment activeItemCount on household doc
      transaction.update(householdRef, {
        activeItemCount: FieldValue.increment(1),
        updatedAt: serverTimestamp,
      });
    });

    return {
      itemId: itemRef.id,
      expirationDate: finalExpirationDate,
    };
  }

  /**
   * Atomic Firestore Transaction for Batch Addition:
   * Adds multiple inventory items at once (e.g. from receipt scan),
   * enforces membership foodLimit, and increments activeItemCount by items.length.
   */
  static async addBatchInventoryItemsWithLimitCheck(
    uid: string,
    membershipId: string,
    householdId: string,
    items: AddInventoryItemInput[]
  ): Promise<{itemIds: string[]}> {
    if (items.length === 0) {
      return {itemIds: []};
    }

    const householdRef = db
      .collection(Collections.HOUSEHOLDS)
      .doc(householdId);

    // 1. Resolve membership food limit
    let foodLimit: number | null = null;
    const membershipDoc = await db
      .collection(Collections.MEMBERSHIPS)
      .doc(membershipId)
      .get();

    if (membershipDoc.exists) {
      foodLimit = membershipDoc.data()?.foodLimit ?? null;
    } else if (membershipId === "free") {
      foodLimit = 30;
    }

    // 2. Pre-calculate expiration dates for all items
    const preparedItems = await Promise.all(
      items.map(async (input) => {
        const purchaseDate = input.purchaseDate ?
          new Date(input.purchaseDate) :
          new Date();

        let finalExp: Date;
        if (input.expirationDate) {
          finalExp = new Date(input.expirationDate);
        } else {
          finalExp = await this.calculateExpirationDate(
            input.foodId,
            input.categoryId,
            input.storageLocationId,
            purchaseDate
          );
        }

        let resolvedPhotoUrl = input.photoUrl || null;
        if (!resolvedPhotoUrl && input.foodId) {
          try {
            const foodDoc = await db.collection(Collections.FOODS).doc(input.foodId).get();
            if (foodDoc.exists) {
              resolvedPhotoUrl = (foodDoc.data()?.photoUrl as string) || null;
            }
          } catch {
            // Non-fatal, continue with null
          }
        }

        return {
          input,
          purchaseDate,
          finalExpirationDate: finalExp,
          normalizedName: normalizeFoodName(input.name),
          photoUrl: resolvedPhotoUrl,
        };
      })
    );

    const serverTimestamp = FieldValue.serverTimestamp();
    const createdItemIds: string[] = [];

    await db.runTransaction(async (transaction) => {
      const householdDoc = await transaction.get(householdRef);
      if (!householdDoc.exists) {
        throwNotFound("Hộ gia đình không tồn tại.");
      }

      const householdData = householdDoc.data()!;
      const members: string[] = householdData.members || [];
      if (!members.includes(uid) && householdData.ownerId !== uid) {
        throwPermissionDenied("Bạn không có quyền thêm món vào gia đình này.");
      }

      const currentActiveCount = (householdData.activeItemCount as number) || 0;
      const newTotal = currentActiveCount + items.length;

      // Check foodLimit restriction for Free accounts
      if (foodLimit !== null && newTotal > foodLimit) {
        throwResourceExhausted(
          `Gói tài khoản của bạn sẽ vượt quá giới hạn tối đa (${foodLimit} món). ` +
          `Hiện tại: ${currentActiveCount}, chuẩn bị thêm: ${items.length}. ` +
          "Vui lòng nâng cấp lên gói Premium để không giới hạn kho lưu trữ!"
        );
      }

      // Add each item
      for (const prep of preparedItems) {
        const itemRef = householdRef.collection(Collections.INVENTORY_ITEMS).doc();
        createdItemIds.push(itemRef.id);

        transaction.set(itemRef, {
          foodId: prep.input.foodId || null,
          name: prep.input.name.trim(),
          normalizedName: prep.normalizedName,
          categoryId: prep.input.categoryId,
          quantity: prep.input.quantity,
          unit: prep.input.unit.trim(),
          remainingPercentage: 100,
          storageLocationId: prep.input.storageLocationId,
          purchaseDate: Timestamp.fromDate(prep.purchaseDate),
          expirationDate: Timestamp.fromDate(prep.finalExpirationDate),
          source: prep.input.source || "receipt_scan",
          status: "active",
          photoUrl: prep.photoUrl || null,
          createdAt: serverTimestamp,
          updatedAt: serverTimestamp,
        });
      }

      // Atomically increment activeItemCount by items.length
      transaction.update(householdRef, {
        activeItemCount: FieldValue.increment(items.length),
        updatedAt: serverTimestamp,
      });
    });

    return {itemIds: createdItemIds};
  }
}

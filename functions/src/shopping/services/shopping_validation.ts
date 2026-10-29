/**
 * Pure input validation for shopping callables (no Firebase imports).
 * Returns a Vietnamese error message, or the cleaned value.
 */

export const MAX_IMPORT_ITEMS = 50;
export const MAX_ITEM_QUANTITY = 10000;
export const STORAGE_LOCATIONS = ["fridge", "freezer"] as const;
/** The generic category is rejected so expiry is computed from a real rule. */
export const OTHER_CATEGORY_ID = "other";

export type StorageLocationId = typeof STORAGE_LOCATIONS[number];

export interface ImportShoppingItemInput {
  shoppingItemId: string;
  storageLocationId: StorageLocationId;
  categoryId: string;
  actualQuantity: number;
  purchaseDate: Date;
}

export type ValidationResult<T> =
  | {ok: true; value: T}
  | {ok: false; error: string};

/**
 * Validates the `items` payload of `importShoppingItemsToInventory`.
 * Category existence is checked separately against Firestore.
 */
export function validateImportItems(
  raw: unknown,
  now: Date = new Date()
): ValidationResult<ImportShoppingItemInput[]> {
  if (!Array.isArray(raw) || raw.length === 0) {
    return {ok: false, error: "Danh sách thực phẩm cần nhập kho không được rỗng."};
  }
  if (raw.length > MAX_IMPORT_ITEMS) {
    return {ok: false, error: `Chỉ nhập tối đa ${MAX_IMPORT_ITEMS} món mỗi lần.`};
  }

  const seen = new Set<string>();
  const items: ImportShoppingItemInput[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== "object") {
      return {ok: false, error: "Dữ liệu món cần nhập kho không hợp lệ."};
    }
    const item = entry as Record<string, unknown>;

    const id = item.shoppingItemId;
    if (typeof id !== "string" || !id.trim()) {
      return {ok: false, error: "Thiếu shoppingItemId."};
    }
    if (seen.has(id)) {
      return {ok: false, error: "Một món không được nhập kho hai lần trong cùng yêu cầu."};
    }
    seen.add(id);

    const quantity = item.actualQuantity;
    if (
      typeof quantity !== "number" ||
      !Number.isFinite(quantity) ||
      quantity <= 0 ||
      quantity > MAX_ITEM_QUANTITY
    ) {
      return {ok: false, error: "Số lượng thực mua phải lớn hơn 0 và không vượt quá 10000."};
    }

    const location = item.storageLocationId;
    if (
      typeof location !== "string" ||
      !(STORAGE_LOCATIONS as readonly string[]).includes(location)
    ) {
      return {ok: false, error: "Vị trí bảo quản không hợp lệ."};
    }

    const categoryId = item.categoryId;
    if (
      typeof categoryId !== "string" ||
      !categoryId.trim() ||
      categoryId.trim() === OTHER_CATEGORY_ID
    ) {
      return {
        ok: false,
        error: "Vui lòng chọn danh mục cụ thể (không phải \"Khác\") cho mỗi món trước khi nhập kho.",
      };
    }

    let purchaseDate = now;
    if (item.purchaseDate !== undefined && item.purchaseDate !== null) {
      if (typeof item.purchaseDate !== "string") {
        return {ok: false, error: "Ngày mua không hợp lệ."};
      }
      purchaseDate = new Date(item.purchaseDate);
      if (Number.isNaN(purchaseDate.getTime())) {
        return {ok: false, error: "Ngày mua không hợp lệ."};
      }
      if (purchaseDate.getTime() > now.getTime() + 86400000) {
        return {ok: false, error: "Ngày mua không được ở tương lai."};
      }
    }

    items.push({
      shoppingItemId: id,
      storageLocationId: location as StorageLocationId,
      categoryId: categoryId.trim(),
      actualQuantity: quantity,
      purchaseDate,
    });
  }

  return {ok: true, value: items};
}

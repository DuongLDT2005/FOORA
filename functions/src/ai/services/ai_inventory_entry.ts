import {normalizeFoodName} from "../../utils/string";
import {suggestFoodCategoryId} from "./ai_food_category";

export interface InventoryEntryLine {
  name: string;
  quantity: number;
  unit: string;
  storageLocationId?: "fridge" | "freezer";
  categoryId?: string;
}

/** Parse only explicit, single-purpose inventory entry requests. */
export function parseInventoryEntry(message: string): InventoryEntryLine[] | null {
  const normalized = normalizeFoodName(message);
  const firstAmount = normalized.search(/\b\d+(?:[.,]\d+)?\s*(?:kg|g|lang|con|bo|qua|hop|chai|lit|goi|tui|cai|cu|trai|mieng|mo)\b/);
  if (firstAmount < 0) return null;
  const beforeAmount = normalized.slice(0, firstAmount);
  if (!/\b(nap|them|mua|cat|cho vao|bo vao|bo sung|ghi vao)\b/.test(beforeAmount) ||
      /\b(dung|tieu thu|bo di|vut|xoa)\b/.test(beforeAmount) ||
      /\b(va|roi)\s+(dung|tieu thu|bo di|vut|xoa)\b/.test(normalized)) {
    return null;
  }

  const storageLocationId = /\b(tu dong|ngan dong)\b/.test(normalized) ?
    "freezer" : "fridge";
  const segments = message.replace(/(\d),(\d)/g, "$1.$2")
    .split(/\s*[,;]\s*|\s+(?:và|với)\s+(?=\d)/iu);
  if (segments.length > 10) return null;
  const lines: InventoryEntryLine[] = [];
  for (const segment of segments) {
    const match = /(\d+(?:[.,]\d+)?)\s*(kg|kilôgam|g|gam|lạng|con|bó|quả|hộp|chai|lít|gói|túi|cái|củ|trái|miếng|mớ)\s+(.+)/iu.exec(segment);
    if (!match) return null;
    const quantity = Number(match[1].replace(",", "."));
    const name = match[3]
      .replace(/\s+(?:dùng|ăn)\s+cho\s+(?:cả\s+)?tuần\s*$/iu, "")
      .trim();
    if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 1000000 ||
        !name || name.length > 100 || /\d/.test(name)) return null;
    const categoryId = suggestFoodCategoryId(name);
    lines.push({name, quantity, unit: match[2].toLowerCase(),
      storageLocationId,
      ...(categoryId ? {categoryId} : {})});
  }
  return lines.length > 0 ? lines : null;
}

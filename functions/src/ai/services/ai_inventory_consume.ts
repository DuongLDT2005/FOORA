import {randomUUID} from "crypto";
import {normalizeFoodName} from "../../utils/string";
import {AssistantInventoryItem, ValidatedAction} from "./ai_model_response";

function convertQuantity(
  qty: number,
  fromUnit: string,
  toUnit: string
): {quantity: number; unit: string} {
  const f = fromUnit.toLowerCase().trim();
  const t = toUnit.toLowerCase().trim();
  if (f === t) return {quantity: qty, unit: toUnit};

  const isFromKg = f === "kg" || f === "kilogam" || f === "kilôgam" || f === "kí" || f === "ky";
  const isFromG = f === "g" || f === "gam" || f === "gram";
  const isFromLang = f === "lạng" || f === "lang";

  const isTargetKg = t === "kg" || t === "kilogam" || t === "kilôgam" || t === "kí" || t === "ky";
  const isTargetG = t === "g" || t === "gam" || t === "gram";
  const isTargetLang = t === "lạng" || t === "lang";

  if (isFromLang && isTargetKg) return {quantity: Number((qty * 0.1).toFixed(4)), unit: toUnit};
  if (isFromG && isTargetKg) return {quantity: Number((qty / 1000).toFixed(4)), unit: toUnit};
  if (isFromKg && isTargetG) return {quantity: Number((qty * 1000).toFixed(4)), unit: toUnit};
  if (isFromLang && isTargetG) return {quantity: Number((qty * 100).toFixed(4)), unit: toUnit};
  if (isFromKg && isTargetLang) return {quantity: Number((qty * 10).toFixed(4)), unit: toUnit};
  if (isFromG && isTargetLang) return {quantity: Number((qty / 100).toFixed(4)), unit: toUnit};

  const isFromLit = f === "l" || f === "lít" || f === "lit";
  const isFromMl = f === "ml" || f === "mililit" || f === "milit";
  const isTargetLit = t === "l" || t === "lít" || t === "lit";
  const isTargetMl = t === "ml" || t === "mililit" || t === "milit";

  if (isFromMl && isTargetLit) return {quantity: Number((qty / 1000).toFixed(4)), unit: toUnit};
  if (isFromLit && isTargetMl) return {quantity: Number((qty * 1000).toFixed(4)), unit: toUnit};

  return {quantity: qty, unit: toUnit};
}

export function parseInventoryConsume(
  message: string,
  inventory: AssistantInventoryItem[]
): {reply: string; actions: ValidatedAction[]} | null {
  const normalized = normalizeFoodName(message);

  // Check if message is asking to consume, discard, or deduct items
  const isConsumeIntent = /\b(dung|da dung|tieu thu|tru|tru kho|an|da an|xuat|xuat kho|bo|vut|bo di|lay|bot|het|da het)\b/iu.test(normalized);
  if (!isConsumeIntent) return null;

  // Make sure it is not an add_inventory intent
  if (/\b(nap|them|mua|cat vao|cho vao|bo vao|bo sung|ghi vao)\b/iu.test(normalized)) {
    return null;
  }

  const segments = message.replace(/(\d),(\d)/g, "$1.$2")
    .split(/\s*[,;]\s*|\s+(?:và|với)\s+(?=\d)/iu);

  const actions: ValidatedAction[] = [];
  const usedItemIds = new Set<string>();

  for (const segment of segments) {
    const match = /(\d+(?:[.,]\d+)?)\s*(kg|kilôgam|kí|ky|g|gam|lạng|lang|con|bó|quả|hộp|chai|lít|lit|l|gói|túi|cái|củ|trái|miếng|mớ)\s+(.+)/iu.exec(segment);
    if (!match) continue;

    const rawQty = Number(match[1].replace(",", "."));
    const rawUnit = match[2].toLowerCase();
    const rawName = match[3]
      .replace(/\s+(?:dùng|ăn|nấu|cho|trong|tủ|hôm nay|nhé|nha|ạ|đi)\b.*$/iu, "")
      .trim();

    if (!Number.isFinite(rawQty) || rawQty <= 0 || !rawName) continue;

    const targetNorm = normalizeFoodName(rawName);

    // Search for matching item in inventory
    let matchedItem: AssistantInventoryItem | undefined;

    // 1. Exact normalized name
    matchedItem = inventory.find(
      (item) => !usedItemIds.has(item.itemId) && item.normalizedName === targetNorm
    );

    // 2. Contains match (e.g., 'bò' matches 'thịt bò' or 'thịt bò' matches 'bò')
    if (!matchedItem) {
      matchedItem = inventory.find(
        (item) =>
          !usedItemIds.has(item.itemId) &&
          (item.normalizedName.includes(targetNorm) || targetNorm.includes(item.normalizedName))
      );
    }

    if (!matchedItem) continue;
    usedItemIds.add(matchedItem.itemId);

    // Convert units (e.g., 5 lạng bò -> 0.5 kg bò)
    const converted = convertQuantity(rawQty, rawUnit, matchedItem.unit);

    actions.push({
      actionId: randomUUID(),
      type: "consume",
      name: matchedItem.name,
      quantity: converted.quantity,
      unit: converted.unit,
      categoryId: matchedItem.categoryId,
      storageLocationId: matchedItem.storageLocationId,
      targetItemId: matchedItem.itemId,
      candidateBatches: [
        {
          itemId: matchedItem.itemId,
          name: matchedItem.name,
          quantity: matchedItem.quantity,
          initialQuantity: matchedItem.initialQuantity,
          unit: matchedItem.unit,
          expirationDate: matchedItem.expirationDate,
          updatedAtMillis: matchedItem.updatedAtMillis,
          createdAtMillis: matchedItem.createdAtMillis,
        },
      ],
      reviewState: "ready",
      resolution: "pending",
    });
  }

  if (actions.length === 0) return null;

  const names = actions.map((a) => `${a.quantity} ${a.unit} ${a.name}`).join(", ");
  return {
    reply: `Tôi đã lập phiếu trừ cho ${names}. Hãy kiểm tra số lượng và nhấn xác nhận để trừ kho.`,
    actions,
  };
}

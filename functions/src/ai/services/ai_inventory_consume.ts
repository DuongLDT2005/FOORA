import {normalizeFoodName} from "../../utils/string";
import {AssistantInventoryItem} from "./ai_model_response";

/** Model-shaped proposal; the shared validator turns it into an action. */
export interface ConsumeProposal {
  type: "consume" | "discard";
  ref: string;
  name: string;
  quantity: number;
  unit: string;
}

/** Lowercase words with the accents the user typed, split like the normalizer. */
function typedWords(value: string): string[] {
  return value.normalize("NFC").toLocaleLowerCase("vi-VN")
    .replace(/[^\p{L}\p{N}]+/gu, " ").trim().split(" ").filter(Boolean);
}

/**
 * True when every word of the spoken name appears in the item name. Words
 * typed with accents must match exactly, because without them "cá" (fish)
 * and "cà" (as in "cà rốt") are the same word.
 * @param {string} spoken Food name from the message.
 * @param {string} itemName Inventory item name.
 * @return {boolean} Whether the item is named by the message.
 */
export function namesItem(spoken: string, itemName: string): boolean {
  const typed = ` ${typedWords(itemName).join(" ")} `;
  const plain = ` ${normalizeFoodName(itemName)} `;
  return typedWords(spoken).every((word) => {
    const unaccented = normalizeFoodName(word);
    return word !== unaccented ?
      typed.includes(` ${word} `) :
      plain.includes(` ${unaccented} `);
  });
}

/**
 * Parses explicit "used/cooked/threw away N unit food" messages without a model
 * call. It only names the food; the validator collects every batch of that
 * food for FEFO and decides whether the proposal needs review. Units are
 * kept as spoken, never converted (PLAN_04 §2.1). Returns null, so the model
 * answers instead, for questions or when any food is missing or ambiguous.
 * @param {string} message User message.
 * @param {AssistantInventoryItem[]} inventory Loaded items.
 * @return {object | null} Reply and proposals, or null.
 */
export function parseInventoryConsume(
  message: string,
  inventory: AssistantInventoryItem[]
): {reply: string; proposals: ConsumeProposal[]} | null {
  const normalized = normalizeFoodName(message);
  if (/[?？]/.test(message) ||
      /\b(khong|ko|chua|nen|co nen|bao nhieu|neu)\b/.test(normalized)) {
    return null;
  }
  // Requests for dish ideas ("gợi ý món ăn từ 2 quả trứng") are not reports.
  if (/\b(goi y|nau gi|mon gi|lam gi|cong thuc|thuc don)\b/.test(normalized)) {
    return null;
  }
  if (!/\b(dung|da dung|tieu thu|tru|tru kho|an|da an|xuat|xuat kho|bo|vut|bo di|lay|bot|het|da het|da nau|vua nau|nau xong|da lam|vua lam)\b/
    .test(normalized)) return null;
  if (/\b(nap|them|mua|cat vao|cho vao|bo vao|bo sung|ghi vao)\b/.test(normalized)) {
    return null;
  }
  const lowered = message.normalize("NFC").toLocaleLowerCase("vi-VN");
  // "bỏ"/"vứt" mean discard; checked with accents so "bò" (beef) is not one.
  const type = /(?:^|\s)(bỏ|vứt)(?=\s|$)/u.test(lowered) ? "discard" : "consume";

  const segments = message.replace(/(\d),(\d)/g, "$1.$2")
    .split(/\s*[,;]\s*|\s+(?:và|với)\s+(?=\d)/iu);
  const proposals: ConsumeProposal[] = [];
  for (const segment of segments) {
    const match = /(\d+(?:[.,]\d+)?)\s*(kg|kilôgam|kí|ky|g|gam|lạng|lang|con|bó|quả|hộp|chai|lít|lit|l|gói|túi|cái|củ|trái|miếng|mớ)\s+(.+)/iu
      .exec(segment);
    if (!match) continue;
    const quantity = Number(match[1].replace(",", "."));
    const unit = match[2].toLocaleLowerCase("vi-VN");
    const spoken = match[3]
      .replace(/\s+(?:dùng|ăn|nấu|cho|trong|tủ|hôm nay|nhé|nha|ạ|đi|rồi)\b.*$/iu, "")
      .trim();
    if (!Number.isFinite(quantity) || quantity <= 0 || !spoken) return null;
    const named = inventory.filter((item) => namesItem(spoken, item.name));
    const foods = new Set(named.map((item) => normalizeFoodName(item.name)));
    // Never guess between different foods (PLAN_04 §2.1).
    if (foods.size !== 1) return null;
    // Inventory is ordered by expiry, so this is the earliest batch; the
    // validator adds the other batches of the same food and unit.
    const item = named.find((candidate) => !candidate.isExpired) ?? named[0];
    proposals.push({type, ref: item.ref, name: item.name, quantity, unit});
  }
  if (proposals.length === 0) return null;
  const verb = type === "discard" ? "bỏ" : "trừ";
  const lines = proposals
    .map((proposal) => `${proposal.quantity} ${proposal.unit} ${proposal.name}`)
    .join(", ");
  return {
    reply: `Tôi đã lập phiếu ${verb} ${lines}. ` +
      "Hãy kiểm tra số lượng và nhấn xác nhận để cập nhật kho.",
    proposals,
  };
}

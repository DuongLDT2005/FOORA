import {Timestamp} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {AssistantInventoryItem} from "./ai_model_response";

const INVENTORY_CONTEXT_LIMIT = 150;
const HISTORY_SCAN_LIMIT = 50;
const HISTORY_REQUEST_LIMIT = 4;
const HISTORY_TEXT_LIMIT = 600;

export interface AssistantHistoryTurn {
  role: "user" | "assistant";
  text: string;
  /** Dishes the assistant suggested in this turn, when there were any. */
  dishes?: number;
}

/**
 * Vietnam calendar day `YYYY-MM-DD` used for quota and expiry dates.
 * @param {Date} now Moment to convert.
 * @return {string} Day in Asia/Ho_Chi_Minh.
 */
export function assistantQuotaDay(now: Date): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const part = (type: string): string =>
    parts.find((value) => value.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

/**
 * Loads up to 150 active items: unexpired items by nearest expiry first, then
 * the most recently expired ones as warnings (PLAN_04 §3.1 step 3).
 * @param {string} householdId Household id.
 * @param {string} today Vietnam day `YYYY-MM-DD`.
 * @return {Promise<object>} Items with short refs, truncation and emptiness.
 */
export async function loadAssistantInventory(
  householdId: string,
  today: string
): Promise<{
  inventory: AssistantInventoryItem[];
  inventoryTruncated: boolean;
  trulyEmpty: boolean;
}> {
  const itemsRef = db.collection(Collections.HOUSEHOLDS)
    .doc(householdId).collection(Collections.INVENTORY_ITEMS);
  const todayStart = Timestamp.fromDate(new Date(`${today}T00:00:00+07:00`));
  // Both halves are read in parallel; the expired half is trimmed afterwards.
  const [usableSnap, expiredSnap] = await Promise.all([
    itemsRef.where("status", "==", "active")
      .where("expirationDate", ">=", todayStart)
      .orderBy("expirationDate").limit(INVENTORY_CONTEXT_LIMIT + 1).get(),
    itemsRef.where("status", "==", "active")
      .where("expirationDate", "<", todayStart)
      .orderBy("expirationDate", "desc").limit(INVENTORY_CONTEXT_LIMIT + 1).get(),
  ]);
  const usableDocs = usableSnap.docs.slice(0, INVENTORY_CONTEXT_LIMIT);
  const remaining = INVENTORY_CONTEXT_LIMIT - usableDocs.length;
  const inventoryTruncated = usableSnap.size > INVENTORY_CONTEXT_LIMIT ||
    expiredSnap.size > remaining;
  const inventoryDocs = [...usableDocs, ...expiredSnap.docs.slice(0, remaining)];
  const inventory = inventoryDocs.map((doc, index): AssistantInventoryItem => {
    const data = doc.data();
    const expiry = data.expirationDate?.toDate?.();
    const expirationDate = expiry instanceof Date &&
      !Number.isNaN(expiry.getTime()) ?
      assistantQuotaDay(expiry) : null;
    return {
      ref: `item${index + 1}`,
      itemId: doc.id,
      name: String(data.name ?? "").slice(0, 100),
      quantity: Number(data.quantity ?? 0),
      unit: String(data.unit ?? "").slice(0, 30),
      expirationDate,
      isExpired: expirationDate === null || expirationDate < today,
      storageLocationId: String(data.storageLocationId ?? ""),
      normalizedName: String(data.normalizedName ?? data.name ?? "")
        .toLocaleLowerCase("vi-VN"),
      categoryId: String(data.categoryId ?? ""),
      initialQuantity: Number(data.initialQuantity ?? 0),
      updatedAtMillis: data.updatedAt?.toMillis?.() ?? 0,
      createdAtMillis: data.createdAt?.toMillis?.() ?? 0,
    };
  });
  const trulyEmpty = inventoryDocs.length === 0 &&
    (await itemsRef.where("status", "==", "active").limit(1).get()).empty;
  return {inventory, inventoryTruncated, trulyEmpty};
}

/**
 * Loads the last four requests of one chat session, filtered before the
 * limit, keeping each user/assistant pair together in chronological order.
 * A new session therefore starts without earlier context.
 * @param {string} uid Caller id.
 * @param {string} sessionId Chat session id.
 * @return {Promise<AssistantHistoryTurn[]>} Conversation turns.
 */
export async function loadAssistantHistory(
  uid: string,
  sessionId: string
): Promise<AssistantHistoryTurn[]> {
  const chatSnap = await db.collection(Collections.USERS).doc(uid)
    .collection(Collections.AI_CHATS)
    .where("sessionId", "==", sessionId)
    .orderBy("createdAt", "desc").limit(HISTORY_SCAN_LIMIT).get();
  const recentRequests = new Map<string, typeof chatSnap.docs>();
  for (const doc of chatSnap.docs) {
    const requestId = String(doc.data().requestId ??
      doc.id.replace(/-(user|assistant)$/, ""));
    if (!recentRequests.has(requestId)) {
      if (recentRequests.size >= HISTORY_REQUEST_LIMIT) continue;
      recentRequests.set(requestId, []);
    }
    recentRequests.get(requestId)!.push(doc);
  }
  return [...recentRequests.values()].flat()
    .sort((left, right) => {
      const leftData = left.data();
      const rightData = right.data();
      const byTime = leftData.createdAt.toMillis() -
        rightData.createdAt.toMillis();
      if (byTime !== 0) return byTime;
      if (leftData.isUser !== rightData.isUser) {
        return leftData.isUser ? -1 : 1;
      }
      return left.id.localeCompare(right.id);
    })
    .map((doc): AssistantHistoryTurn => {
      const data = doc.data();
      const dishes = !data.isUser && Array.isArray(data.recipes) ?
        data.recipes.length : 0;
      return {
        role: data.isUser ? "user" : "assistant",
        text: String(data.content ?? "").slice(0, HISTORY_TEXT_LIMIT) +
          (data.isUser ? "" : recipeSummary(data.recipes)),
        ...(dishes > 0 ? {dishes} : {}),
      };
    });
}

/**
 * One line per suggested dish with its ingredient amounts, so "I cooked that
 * one" in a later turn can reuse the amounts the assistant proposed.
 * @param {unknown} recipes Stored validated recipes.
 * @return {string} Summary appended to the assistant turn, or "".
 */
export function recipeSummary(recipes: unknown): string {
  if (!Array.isArray(recipes)) return "";
  const lines = recipes.slice(0, 3).flatMap((recipe) => {
    if (!recipe || typeof recipe !== "object" ||
        !Array.isArray(recipe.ingredients)) return [];
    const parts = (recipe.ingredients as unknown[]).slice(0, 15)
      .flatMap((raw) => {
        if (!raw || typeof raw !== "object") return [];
        const item = raw as Record<string, unknown>;
        if (typeof item.name !== "string") return [];
        const amount = typeof item.quantity === "number" ?
          ` ${item.quantity} ${typeof item.unit === "string" ? item.unit : ""}` :
          "";
        return [`${item.name}${amount}`.trim() +
          (typeof item.itemId === "string" ? "" : " (cần mua)")];
      });
    return parts.length > 0 ?
      [`${String(recipe.title ?? "").slice(0, 120)}: ${parts.join(", ")}`] : [];
  });
  return lines.length > 0 ? `
Gợi ý đã đưa: ${lines.join("; ")}` : "";
}

import {createHash, randomUUID} from "crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {InventoryService} from "../../inventory/services/inventory_service";
import {
  MasterFoodItem,
  loadMasterFoods,
} from "../../inventory/services/food_matcher";
import {MembershipService} from "../../membership/services/membership_service";
import {AuthenticatedUser} from "../../types";
import {verifyHouseholdAccess} from "../../utils/auth";
import {normalizeFoodName} from "../../utils/string";
import {
  throwFailedPrecondition,
  throwPermissionDenied,
  throwResourceExhausted,
} from "../../utils/errors";
import {
  ValidatedAction,
  ValidatedRecipe,
  validateAssistantResponse,
} from "./ai_model_response";
import {parseInventoryEntry} from "./ai_inventory_entry";
import {parseInventoryConsume} from "./ai_inventory_consume";
import {assignCatalogFood} from "./ai_inventory_food";
import {
  AssistantHistoryTurn,
  assistantQuotaDay,
  loadAssistantHistory,
  loadAssistantInventory,
} from "./assistant_context";
import {generateAssistantJson} from "./assistant_gemini";

export {assistantQuotaDay} from "./assistant_context";
export {assistantModelError} from "./assistant_gemini";

/** Longer than the callable timeout so a running request is never refunded. */
const REQUEST_LEASE_MS = 120000;
const SESSION_TITLE_LENGTH = 80;
const SESSION_PREVIEW_LENGTH = 140;

export interface AiAssistantInput {
  requestId: string;
  /** Client-generated chat session; history and context stay inside it. */
  sessionId: string;
  householdId: string;
  message: string;
  inputMode: "text" | "voice";
}

export interface AiAssistantResult {
  messageId: string;
  reply: string;
  actions: ValidatedAction[];
  recipes: ValidatedRecipe[];
  quota: {used: number; limit: number | null; day: string};
}

type Reservation =
  | {kind: "completed"; result: AiAssistantResult}
  | {kind: "reserved"; attemptId: string; day: string};

export function requestedMenuDishCount(question: string): number {
  const text = normalizeFoodName(question);
  const explicit = /\b([2-3])\s+mon\b/.exec(text);
  if (explicit) return Number(explicit[1]);
  if (/\b(thuc don|bua an|mam com|khong phai 1 mon|khong phai mot mon)\b/
    .test(text)) return 2;
  return 0;
}

export function requestedServings(question: string): number | null {
  const match = /\b(\d{1,2})\s+(nguoi|thanh vien)\b/
    .exec(normalizeFoodName(question));
  const count = match ? Number(match[1]) : null;
  return count !== null && count >= 1 && count <= 20 ? count : null;
}

/**
 * Dishes a follow-up must suggest again: changing only the serving count of
 * the previous suggestion ("điều chỉnh cho 4 người") keeps all its dishes,
 * and asking for other or quicker dishes needs at least one. Without this
 * the model sometimes answered such follow-ups in text only, dropping the
 * dish cards and their amounts.
 * @param {string} question User message.
 * @param {AssistantHistoryTurn[]} history Earlier turns of the session.
 * @return {number} Minimum dishes in the answer, or 0 for no requirement.
 */
export function requestedFollowUpDishCount(
  question: string,
  history: AssistantHistoryTurn[]
): number {
  const last = [...history].reverse().find((turn) => turn.role === "assistant");
  const previous = last?.dishes ?? 0;
  if (previous === 0) return 0;
  const text = normalizeFoodName(question);
  if (/\b(mon khac|doi mon|mon nao|nhanh hon|de hon|re hon)\b/.test(text)) {
    return 1;
  }
  return requestedServings(question) !== null ? previous : 0;
}

export function replyForEmptyInventory(question: string): string | null {
  const text = normalizeFoodName(question);
  // Only answer simple read-only questions here. Inventory commands must reach
  // the model so it can propose an action even when there are no active items.
  if (/\b(mua|them|nap|cat|luu|ghi|bo|vut|xoa|dung|tieu thu|cap nhat)\b/
    .test(text) || /\b(cho vao|bo vao|bo sung|dat so luong)\b/.test(text)) {
    return null;
  }
  if (!/\b(tu|kho|thuc pham|nguyen lieu|het han|nau|mon|con gi)\b/
    .test(text)) return null;
  if (!/[?？]/.test(question) &&
      !/\b(con gi|co gi|sap het han|nen dung|nen an|nau gi|mon gi|bao nhieu)\b/
        .test(text)) return null;
  return "Tủ của bạn hiện chưa có thực phẩm nào, nên chưa có món sắp hết " +
    "hạn để gợi ý. Hãy thêm thực phẩm vào tủ rồi hỏi lại nhé.";
}

type ValidatedAnswer = NonNullable<ReturnType<typeof validateAssistantResponse>>;

/**
 * True when the reply announces a receipt (phiếu) but no action survived
 * validation, which would leave the user waiting for a card that never shows.
 * @param {ValidatedAnswer} answer Validated answer.
 * @return {boolean} Whether the reply promises a missing receipt.
 */
export function promisesMissingReceipt(answer: ValidatedAnswer): boolean {
  return answer.actions.length === 0 && /phiếu/i.test(answer.reply);
}

const MISSING_RECEIPT_REPLY = "Mình chưa xác định được món nào trong tủ " +
  "để cập nhật. Bạn nói rõ tên món và lượng đã dùng giúp mình nhé.";

export class AiAssistantService {
  static async send(
    user: AuthenticatedUser,
    input: AiAssistantInput,
    apiKey: string
  ): Promise<AiAssistantResult> {
    if (user.activeHouseholdId !== input.householdId) {
      throwPermissionDenied("Tủ lạnh này không phải tủ đang được chọn.");
    }
    const startedAt = Date.now();
    const today = assistantQuotaDay(new Date());
    const userRef = db.collection(Collections.USERS).doc(user.uid);
    const sessionRef = userRef.collection(Collections.AI_SESSIONS)
      .doc(input.sessionId);
    // The model context loads while access and quota are checked; it is only
    // used after both pass, and a failed check leaves it unread.
    const contextLoad = Promise.all([
      loadAssistantInventory(input.householdId, today),
      loadAssistantHistory(user.uid, input.sessionId),
      sessionRef.get(),
    ]);
    contextLoad.catch(() => undefined);
    // Plan limits come from the subscription, not the users.membershipId
    // cache (FUNCTIONS_GUIDE §1.5).
    const [, limit] = await Promise.all([
      verifyHouseholdAccess(user.uid, input.householdId),
      MembershipService.resolveMembershipId(user.uid)
        .then((membershipId) => MembershipService.getLimits(membershipId))
        .then((limits) => limits.aiAssistantDailyQuota),
    ]);
    if (limit === undefined ||
        (limit !== null && (!Number.isInteger(limit) || limit < 0))) {
      throwFailedPrecondition("Chưa cấu hình hạn mức trợ lý AI cho gói thành viên.");
    }
    const usageDays = userRef.collection(Collections.AI_USAGE_DAYS);
    const chats = userRef.collection(Collections.AI_CHATS);
    const requestRef = userRef.collection(Collections.AI_REQUESTS)
      .doc(input.requestId);
    const hash = createHash("sha256")
      .update(JSON.stringify(input)).digest("hex");

    const reservation = await db.runTransaction(async (tx): Promise<Reservation> => {
      const requestSnap = await tx.get(requestRef);
      const existing = requestSnap.data();
      if (existing && existing.payloadHash !== hash) {
        throwFailedPrecondition("Mã gửi này đã được dùng cho câu hỏi khác.");
      }
      if (existing?.status === "completed") {
        return {kind: "completed", result: existing.result as AiAssistantResult};
      }
      if (existing?.status === "pending" &&
          existing.leaseExpiresAt?.toMillis() > Date.now()) {
        throwFailedPrecondition("Câu hỏi đang được xử lý. Vui lòng thử lại sau.");
      }
      const day = existing?.status === "pending" ?
        existing.quotaDay as string : today;
      const usageRef = usageDays.doc(day);
      const usageSnap = await tx.get(usageRef);
      const used = Number(usageSnap.data()?.used ?? 0);
      if (!Number.isInteger(used) || used < 0) {
        throwFailedPrecondition("Bộ đếm lượt hỏi AI không hợp lệ.");
      }
      const alreadyReserved = existing?.status === "pending" &&
        existing.quotaReserved === true;
      if (!alreadyReserved && limit !== null && used >= limit) {
        throwResourceExhausted("Bạn đã hết lượt hỏi AI hôm nay.");
      }
      const attemptId = randomUUID();
      tx.set(usageRef, {
        used: used + (alreadyReserved ? 0 : 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      tx.set(requestRef, {
        payloadHash: hash,
        householdId: input.householdId,
        status: "pending",
        quotaDay: day,
        quotaReserved: true,
        attemptId,
        leaseExpiresAt: Timestamp.fromMillis(Date.now() + REQUEST_LEASE_MS),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {kind: "reserved", attemptId, day};
    });
    if (reservation.kind === "completed") return reservation.result;
    const reservedAt = Date.now();

    try {
      const [{inventory, inventoryTruncated, trulyEmpty}, history, session] =
        await contextLoad;
      const contextAt = Date.now();
      if (session.exists && session.data()?.householdId !== input.householdId) {
        throwPermissionDenied("Cuộc trò chuyện này thuộc tủ lạnh khác.");
      }
      const entryLines = parseInventoryEntry(input.message);
      const consume = entryLines ? null :
        parseInventoryConsume(input.message, inventory);
      const localReply = !entryLines && !consume && trulyEmpty ?
        replyForEmptyInventory(input.message) : null;
      if (!entryLines && !consume && !localReply && !apiKey) {
        throwFailedPrecondition("Dịch vụ AI chưa được cấu hình.");
      }
      const minimumMenuDishes = requestedMenuDishCount(input.message);
      const requiredDishes = Math.max(minimumMenuDishes,
        requestedFollowUpDishCount(input.message, history));
      const servings = requestedServings(input.message);
      const promptContext = {
        today,
        // One short line per item keeps the prompt (and model latency) small;
        // the line format is described in the system instruction.
        inventory: inventory.map((item) => [
          item.ref, item.name, item.quantity, item.unit,
          item.expirationDate ?? "?", item.storageLocationId,
          ...(item.isExpired ? ["quá hạn"] : []),
        ].map((field) => String(field).replace(/\|/g, "/")).join("|")),
        inventoryTruncated,
        history,
        question: input.message,
        minimumMenuDishes,
        servings,
      };

      // Local parsers produce the same JSON as the model, so one validator
      // decides refs, FEFO candidates and review state for every answer.
      let model: string;
      let responseText: string | undefined;
      let fromModel = false;
      if (entryLines) {
        model = "local-inventory-entry";
        responseText = JSON.stringify({
          reply: `Tôi đã lập phiếu nhập ${entryLines.length} món. ` +
            "Hãy kiểm tra thông tin và xác nhận để thêm vào tủ.",
          recipes: [],
          actions: entryLines.map((line) => ({type: "add_inventory", ...line})),
        });
      } else if (consume) {
        model = "local-inventory-consume";
        responseText = JSON.stringify({
          reply: consume.reply, recipes: [], actions: consume.proposals,
        });
      } else if (localReply) {
        model = "local-empty-inventory";
        responseText = JSON.stringify({reply: localReply, recipes: [], actions: []});
      } else {
        const hasUsable = inventory
          .some((item) => !item.isExpired && item.quantity > 0);
        // An answer that is invalid, promises a missing receipt or returns a
        // short menu lets the fallback model answer instead.
        ({text: responseText, model} = await generateAssistantJson(apiKey,
          JSON.stringify(promptContext), (text) => {
            const answer = validateAssistantResponse(
              text, inventory, inventoryTruncated);
            return answer !== null && !promisesMissingReceipt(answer) &&
              !(requiredDishes > 0 && hasUsable &&
                answer.recipes.length < requiredDishes);
          }));
        model = `gemini:${model}`;
        fromModel = true;
      }
      const answeredAt = Date.now();
      const validated = validateAssistantResponse(
        responseText, inventory, inventoryTruncated);
      if (!validated) {
        throwFailedPrecondition("Trợ lý AI trả lời không hợp lệ. Vui lòng thử lại.");
      }
      const reply = promisesMissingReceipt(validated) ?
        MISSING_RECEIPT_REPLY : validated.reply;
      // The serving count the user asked for is known for certain.
      const recipes = servings === null ? validated.recipes :
        validated.recipes.map((recipe) => ({...recipe, servings}));
      const actions = await AiAssistantService.enrichAddActions(validated.actions);

      const stored = await db.runTransaction(async (tx): Promise<AiAssistantResult> => {
        const current = await tx.get(requestRef);
        if (current.data()?.status !== "pending" ||
            current.data()?.attemptId !== reservation.attemptId) {
          throwFailedPrecondition("Phiên hỏi AI đã hết hạn. Vui lòng gửi lại.");
        }
        const usageSnap = await tx.get(usageDays.doc(reservation.day));
        const sessionSnap = await tx.get(sessionRef);
        const result: AiAssistantResult = {
          messageId: `${input.requestId}-assistant`,
          reply,
          actions,
          recipes,
          quota: {
            used: Number(usageSnap.data()?.used ?? 0),
            limit,
            day: reservation.day,
          },
        };
        const now = FieldValue.serverTimestamp();
        const preview = reply.slice(0, SESSION_PREVIEW_LENGTH);
        if (sessionSnap.exists) {
          tx.update(sessionRef, {lastMessage: preview, updatedAt: now,
            messageCount: FieldValue.increment(2)});
        } else {
          tx.set(sessionRef, {
            householdId: input.householdId,
            title: input.message.slice(0, SESSION_TITLE_LENGTH),
            lastMessage: preview,
            messageCount: 2,
            createdAt: now,
            updatedAt: now,
          });
        }
        tx.set(chats.doc(`${input.requestId}-user`), {
          householdId: input.householdId,
          sessionId: input.sessionId,
          requestId: input.requestId,
          content: input.message,
          inputMode: input.inputMode,
          isUser: true,
          createdAt: now,
        });
        tx.set(chats.doc(result.messageId), {
          householdId: input.householdId,
          sessionId: input.sessionId,
          requestId: input.requestId,
          content: reply,
          isUser: false,
          model,
          actions,
          recipes,
          ...(actions.length > 0 ? {actionStatus: "proposed"} : {}),
          createdAt: now,
        });
        tx.update(requestRef, {
          status: "completed",
          result,
          updatedAt: now,
        });
        return result;
      });
      const doneAt = Date.now();
      logger.info("[AiAssistantService] Timings", {
        model,
        checksMs: reservedAt - startedAt,
        contextWaitMs: contextAt - reservedAt,
        modelMs: fromModel ? answeredAt - contextAt : 0,
        storeMs: doneAt - answeredAt,
        totalMs: doneAt - startedAt,
      });
      return stored;
    } catch (error) {
      try {
        await AiAssistantService.refund(requestRef,
          usageDays.doc(reservation.day), reservation.attemptId);
      } catch (refundError) {
        // The cleanup scheduler refunds the expired lease; keep the real error.
        logger.error("[AiAssistantService] Refund failed", refundError);
      }
      throw error;
    }
  }

  /**
   * Marks a failed request and returns its reserved quota exactly once.
   * @param {FirebaseFirestore.DocumentReference} requestRef Request record.
   * @param {FirebaseFirestore.DocumentReference} usageRef Daily counter.
   * @param {string} attemptId Attempt that reserved the quota.
   * @return {Promise<void>} Resolves when the refund is committed.
   */
  private static async refund(
    requestRef: FirebaseFirestore.DocumentReference,
    usageRef: FirebaseFirestore.DocumentReference,
    attemptId: string
  ): Promise<void> {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(requestRef);
      if (current.data()?.status !== "pending" ||
          current.data()?.attemptId !== attemptId) return;
      const usageSnap = await tx.get(usageRef);
      tx.set(usageRef, {
        used: Math.max(0, Number(usageSnap.data()?.used ?? 0) - 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      tx.update(requestRef, {
        status: "failed",
        quotaReserved: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  /**
   * Links add_inventory proposals to the `foods` catalog the same way receipt
   * scanning does (name, foodId, category, unit, photo) and estimates expiry
   * from the shelf-life rules (DATABASE.md, AI code rules §15). Every step is
   * optional: the review UI still lets users fix what the catalog left out.
   * @param {ValidatedAction[]} proposed Validated actions.
   * @return {Promise<ValidatedAction[]>} Actions ready to store.
   */
  private static async enrichAddActions(
    proposed: ValidatedAction[]
  ): Promise<ValidatedAction[]> {
    if (!proposed.some((action) => action.type === "add_inventory")) {
      return proposed;
    }
    let foods: MasterFoodItem[] = [];
    try {
      foods = await loadMasterFoods();
    } catch (error) {
      logger.warn("[AiAssistantService] Food catalog unavailable", error);
    }
    const now = new Date();
    return Promise.all(proposed.map(async (action) => {
      const linked = assignCatalogFood(action, foods);
      if (linked.type !== "add_inventory" || !linked.categoryId) return linked;
      try {
        const expiry = await InventoryService.calculateExpirationDate(
          linked.foodId ?? null, linked.categoryId,
          linked.storageLocationId ?? "fridge", now);
        return {...linked, expirationDate: assistantQuotaDay(expiry)};
      } catch {
        return linked;
      }
    }));
  }
}

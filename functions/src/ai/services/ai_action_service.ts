import {createHash} from "crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {InventoryService} from "../../inventory/services/inventory_service";
import {AuthenticatedUser} from "../../types";
import {throwFailedPrecondition, throwInvalidArgument,
  throwPermissionDenied, throwResourceExhausted} from "../../utils/errors";
import {normalizeFoodName} from "../../utils/string";
import {ActionCandidate, ValidatedAction} from "./ai_model_response";

export interface AiDecision {
  actionId: string;
  accept: boolean;
  targetItemId?: string;
  batchAllocations?: Array<{itemId: string; quantity: number}>;
  name?: string;
  foodId?: string | null;
  quantity?: number;
  unit?: string;
  categoryId?: string;
  storageLocationId?: "fridge" | "freezer";
  expirationDate?: string;
}

export interface ApplyAiResult {
  messageId: string;
  actionStatus: "applied" | "dismissed" | "expired";
  results: Array<{actionId: string; resolution: "applied" | "dismissed" | "expired";
    itemIds: string[]}>;
}

interface PreparedAdd {
  expirationDate: Date;
}

const decisionKeys = new Set([
  "actionId", "accept", "targetItemId", "batchAllocations", "name",
  "foodId", "quantity", "unit", "categoryId", "storageLocationId",
  "expirationDate",
]);

const safeId = (value: unknown): value is string =>
  typeof value === "string" && /^[a-zA-Z0-9_-]{1,128}$/.test(value);

function validNumber(value: unknown, allowZero = false): value is number {
  return typeof value === "number" && Number.isFinite(value) &&
    (allowZero ? value >= 0 : value > 0) && value <= 1000000;
}

function vietnamDate(value: Date): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Ho_Chi_Minh", year: "numeric",
    month: "2-digit", day: "2-digit",
  }).formatToParts(value);
  const part = (type: string): string =>
    parts.find((item) => item.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function normalizedDecisions(decisions: AiDecision[]): string {
  return JSON.stringify([...decisions].sort((a, b) =>
    a.actionId.localeCompare(b.actionId)).map((decision) => ({
    actionId: decision.actionId,
    accept: decision.accept,
    targetItemId: decision.targetItemId ?? null,
    batchAllocations: decision.batchAllocations ?
      [...decision.batchAllocations].sort((a, b) =>
        a.itemId.localeCompare(b.itemId)) : null,
    name: decision.name ?? null,
    foodId: decision.foodId ?? null,
    quantity: decision.quantity ?? null,
    unit: decision.unit ?? null,
    categoryId: decision.categoryId ?? null,
    storageLocationId: decision.storageLocationId ?? null,
    expirationDate: decision.expirationDate ?? null,
  })));
}

export function allocateFefo(
  candidates: ActionCandidate[],
  quantity: number
): Array<{itemId: string; quantity: number}> | null {
  if (!validNumber(quantity)) return null;
  let remaining = quantity;
  const result: Array<{itemId: string; quantity: number}> = [];
  const ordered = [...candidates].sort((a, b) =>
    (a.expirationDate ?? "9999").localeCompare(b.expirationDate ?? "9999") ||
    a.createdAtMillis - b.createdAtMillis ||
    a.itemId.localeCompare(b.itemId));
  for (const candidate of ordered) {
    if (remaining <= 0) break;
    const take = Math.min(candidate.quantity, remaining);
    if (take > 0) result.push({itemId: candidate.itemId, quantity: take});
    remaining = Number((remaining - take).toFixed(6));
  }
  return remaining <= 0 ? result : null;
}

export class AiActionService {
  static async apply(
    user: AuthenticatedUser,
    messageId: string,
    decisions: AiDecision[]
  ): Promise<ApplyAiResult> {
    if (typeof messageId !== "string" || !/^[0-9a-f-]{36}-assistant$/i.test(messageId) ||
        !Array.isArray(decisions) || decisions.length === 0 || decisions.length > 10) {
      throwInvalidArgument("Danh sách xác nhận AI không hợp lệ.");
    }
    const seen = new Set<string>();
    for (const decision of decisions) {
      if (!decision || typeof decision !== "object" || Array.isArray(decision) ||
          typeof decision.actionId !== "string" || seen.has(decision.actionId) ||
          typeof decision.accept !== "boolean" ||
          Object.keys(decision).some((key) => !decisionKeys.has(key))) {
        throwInvalidArgument("Quyết định AI không hợp lệ hoặc bị trùng.");
      }
      seen.add(decision.actionId);
      if (!decision.accept && Object.keys(decision).some((key) =>
        key !== "actionId" && key !== "accept")) {
        throwInvalidArgument("Action bị bỏ không được kèm giá trị sửa.");
      }
      if (!decision.accept) continue;
      if ((decision.targetItemId !== undefined && !safeId(decision.targetItemId)) ||
          (decision.categoryId !== undefined && !safeId(decision.categoryId)) ||
          (decision.foodId !== undefined && decision.foodId !== null &&
            !safeId(decision.foodId)) ||
          (decision.quantity !== undefined && !validNumber(decision.quantity, true)) ||
          (decision.name !== undefined &&
            (typeof decision.name !== "string" || !decision.name.trim() ||
              decision.name.length > 100)) ||
          (decision.unit !== undefined &&
            (typeof decision.unit !== "string" || !decision.unit.trim() ||
              decision.unit.length > 30)) ||
          (decision.expirationDate !== undefined &&
            (typeof decision.expirationDate !== "string" ||
              !/^\d{4}-\d{2}-\d{2}$/.test(decision.expirationDate))) ||
          (decision.storageLocationId !== undefined &&
            decision.storageLocationId !== "fridge" &&
            decision.storageLocationId !== "freezer")) {
        throwInvalidArgument("Giá trị sửa của action không hợp lệ.");
      }
      if (decision.batchAllocations !== undefined) {
        const allocations = decision.batchAllocations;
        if (!Array.isArray(allocations) || allocations.length === 0 ||
            allocations.length > 20) {
          throwInvalidArgument("Phân bổ batch không hợp lệ.");
        }
        const invalid = allocations.some((item) => {
          return !item || typeof item !== "object" || Array.isArray(item) ||
            Object.keys(item).some((key) => key !== "itemId" && key !== "quantity") ||
            !safeId(item.itemId) || !validNumber(item.quantity);
        });
        if (invalid ||
            new Set(allocations.map((item) => item.itemId)).size !== allocations.length) {
          throwInvalidArgument("Phân bổ batch không hợp lệ.");
        }
      }
    }
    const hash = createHash("sha256")
      .update(normalizedDecisions(decisions)).digest("hex");
    const messageRef = db.collection(Collections.USERS).doc(user.uid)
      .collection(Collections.AI_CHATS).doc(messageId);
    const preflight = await messageRef.get();
    const preflightData = preflight.data();
    if (!preflightData || preflightData.isUser ||
        preflightData.householdId !== user.activeHouseholdId) {
      throwPermissionDenied("Tin nhắn AI không thuộc tủ lạnh đang chọn.");
    }
    const proposals = preflightData.actions as ValidatedAction[] | undefined;
    if (!Array.isArray(proposals) || proposals.length !== decisions.length ||
        !decisions.every((decision) => proposals.some((action) =>
          action.actionId === decision.actionId))) {
      throwInvalidArgument("Phải quyết định tất cả action đã đề xuất.");
    }
    for (const decision of decisions.filter((item) => item.accept)) {
      const action = proposals.find((item) => item.actionId === decision.actionId)!;
      const addFields = decision.name !== undefined || decision.foodId !== undefined ||
        decision.categoryId !== undefined || decision.storageLocationId !== undefined ||
        decision.expirationDate !== undefined;
      if ((action.type !== "add_inventory" && addFields) ||
          (action.type === "add_inventory" &&
            (decision.targetItemId !== undefined ||
              decision.batchAllocations !== undefined)) ||
          (action.type === "set_quantity" &&
            decision.batchAllocations !== undefined)) {
        throwInvalidArgument("Trường sửa không phù hợp loại action.");
      }
    }

    const prepared = new Map<string, PreparedAdd>();
    for (const decision of decisions) {
      const action = proposals.find((item) => item.actionId === decision.actionId)!;
      if (!decision.accept || action.type !== "add_inventory") continue;
      const name = decision.name ?? action.name;
      const quantity = decision.quantity ?? action.quantity;
      const unit = decision.unit ?? action.unit;
      if (typeof name !== "string" || !name.trim() || name.length > 100 ||
          !validNumber(quantity) || typeof unit !== "string" || !unit.trim() ||
          unit.length > 30 || !decision.categoryId ||
          !/^[a-zA-Z0-9_-]{1,128}$/.test(decision.categoryId) ||
          !decision.storageLocationId ||
          (decision.foodId && !/^[a-zA-Z0-9_-]{1,128}$/.test(decision.foodId)) ||
          (decision.expirationDate &&
            !/^\d{4}-\d{2}-\d{2}$/.test(decision.expirationDate))) {
        throwInvalidArgument("Thông tin món thêm vào kho chưa đầy đủ.");
      }
      const expirationDate = decision.expirationDate ?
        new Date(`${decision.expirationDate}T00:00:00+07:00`) :
        await InventoryService.calculateExpirationDate(
          decision.foodId ?? null,
          decision.categoryId ?? "",
          decision.storageLocationId ?? "",
          new Date()
        );
      if (Number.isNaN(expirationDate.getTime()) ||
          (decision.expirationDate &&
            vietnamDate(expirationDate) !== decision.expirationDate)) {
        throwInvalidArgument("Hạn sử dụng không hợp lệ.");
      }
      if (expirationDate.getTime() < Date.now() - 86400000) {
        throwInvalidArgument("Hạn sử dụng không được trước ngày mua.");
      }
      prepared.set(decision.actionId, {expirationDate});
    }

    // Same plan as manual adds: the household owner's subscription decides
    // foodLimit (FUNCTIONS_GUIDE §1.5, PLAN_04 §8.3).
    const membershipId = await InventoryService.resolveHouseholdMembershipId(
      preflightData.householdId as string);

    return db.runTransaction(async (tx): Promise<ApplyAiResult> => {
      const messageSnap = await tx.get(messageRef);
      const message = messageSnap.data();
      if (!message || message.isUser ||
          message.householdId !== user.activeHouseholdId) {
        throwPermissionDenied("Tin nhắn AI không còn hợp lệ.");
      }
      if (message.actionStatus === "applied" ||
          message.actionStatus === "dismissed" ||
          message.actionStatus === "expired") {
        if (message.decisionsHash !== hash) {
          throwFailedPrecondition("Tin nhắn này đã được xác nhận với quyết định khác.");
        }
        return message.applyResult as ApplyAiResult;
      }
      if (message.actionStatus !== "proposed") {
        throwFailedPrecondition("Đề xuất AI đã hết hạn hoặc không còn hiệu lực.");
      }
      const actions = message.actions as ValidatedAction[];
      if (!Array.isArray(actions) || actions.length !== decisions.length ||
          !decisions.every((decision) => actions.some((action) =>
            action.actionId === decision.actionId))) {
        throwFailedPrecondition("Đề xuất AI đã thay đổi. Hãy tải lại.");
      }
      const createdAt = message.createdAt as Timestamp | undefined;
      if (!createdAt?.toMillis || Date.now() - createdAt.toMillis() > 30 * 60000) {
        const results = actions.map((action) => ({
          actionId: action.actionId,
          resolution: "expired" as const,
          itemIds: [] as string[],
        }));
        const result: ApplyAiResult = {messageId, actionStatus: "expired", results};
        tx.update(messageRef, {
          actionStatus: "expired",
          decisionsHash: hash,
          actions: actions.map((action) => ({...action, resolution: "expired"})),
          applyResult: result,
        });
        return result;
      }
      const householdId = message.householdId as string;
      const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);
      const household = await tx.get(householdRef);
      const members = household.data()?.members as string[] | undefined;
      if (!household.exists ||
          (household.data()?.ownerId !== user.uid && !members?.includes(user.uid))) {
        throwPermissionDenied("Bạn không còn là thành viên của tủ lạnh này.");
      }
      const itemRefs = householdRef.collection(Collections.INVENTORY_ITEMS);
      const selectedIds = new Set<string>();
      for (const decision of decisions.filter((item) => item.accept)) {
        const action = actions.find((item) => item.actionId === decision.actionId)!;
        if (action.type === "add_inventory") continue;
        for (const candidate of action.candidateBatches) selectedIds.add(candidate.itemId);
      }
      const current = new Map<string, FirebaseFirestore.DocumentData>();
      for (const itemId of selectedIds) {
        const snap = await tx.get(itemRefs.doc(itemId));
        if (!snap.exists) throwFailedPrecondition(`Batch ${itemId} đã bị xóa.`);
        current.set(itemId, snap.data()!);
      }
      const acceptedAdds = decisions.filter((decision) => decision.accept &&
        actions.find((action) => action.actionId === decision.actionId)?.type ===
          "add_inventory");
      const foodPhotos = new Map<string, string | null>();
      for (const decision of acceptedAdds) {
        const category = await tx.get(db.collection(Collections.FOOD_CATEGORIES)
          .doc(decision.categoryId ?? ""));
        const location = await tx.get(db.collection(Collections.STORAGE_LOCATIONS)
          .doc(decision.storageLocationId ?? ""));
        if (!category.exists || category.data()?.isActive === false ||
            !location.exists || location.data()?.isActive === false) {
          throwInvalidArgument("Danh mục hoặc vị trí bảo quản không hợp lệ.");
        }
        if (decision.foodId) {
          const food = await tx.get(db.collection(Collections.FOODS)
            .doc(decision.foodId));
          if (!food.exists || food.data()?.isActive === false ||
              food.data()?.categoryId !== decision.categoryId) {
            throwInvalidArgument("Thực phẩm chuẩn không hợp lệ.");
          }
          foodPhotos.set(decision.foodId,
            (food.data()?.photoUrl as string | undefined) || null);
        }
      }
      const membership = await tx.get(db.collection(Collections.MEMBERSHIPS)
        .doc(membershipId));
      if (!membership.exists || membership.data()?.isActive === false) {
        throwFailedPrecondition("Cấu hình gói thành viên chưa sẵn sàng.");
      }
      const foodLimit = typeof membership.data()?.foodLimit === "number" ?
        membership.data()!.foodLimit as number : null;
      if (foodLimit !== null &&
          (!Number.isInteger(foodLimit) || foodLimit < 0)) {
        throwFailedPrecondition("Giới hạn món trong gói không hợp lệ.");
      }
      const activeCount = foodLimit === null ?
        Number(household.data()?.activeItemCount ?? 0) :
        (await tx.get(itemRefs.where("status", "==", "active")
          .limit(foodLimit + 1))).size;
      const updates = new Map<string, {quantity: number; status: string;
        remainingPercentage: number}>();
      const creations: Array<{actionId: string; itemId: string;
        data: FirebaseFirestore.DocumentData}> = [];
      const results: ApplyAiResult["results"] = [];
      const allUsedIds = new Set<string>();
      for (const decision of decisions) {
        const action = actions.find((item) => item.actionId === decision.actionId)!;
        if (!decision.accept) {
          results.push({actionId: action.actionId, resolution: "dismissed", itemIds: []});
          continue;
        }
        const quantity = decision.quantity ?? action.quantity;
        const unit = decision.unit ?? action.unit;
        if (action.type === "add_inventory") {
          const name = decision.name ?? action.name;
          if (typeof name !== "string" || !name.trim() || name.length > 100 ||
              !validNumber(quantity) || typeof unit !== "string" || !unit.trim() ||
              unit.length > 30 || !decision.categoryId ||
              !decision.storageLocationId) {
            throwInvalidArgument("Thông tin món thêm vào kho chưa đầy đủ.");
          }
          const itemRef = itemRefs.doc();
          creations.push({actionId: action.actionId, itemId: itemRef.id, data: {
            foodId: decision.foodId ?? null,
            name: name.trim(),
            normalizedName: normalizeFoodName(name),
            categoryId: decision.categoryId,
            quantity,
            initialQuantity: quantity,
            unit: unit.trim(),
            remainingPercentage: 100,
            storageLocationId: decision.storageLocationId,
            purchaseDate: Timestamp.now(),
            expirationDate: Timestamp.fromDate(prepared.get(action.actionId)!.expirationDate),
            source: "manual",
            status: "active",
            photoUrl: decision.foodId ?
              foodPhotos.get(decision.foodId) ?? null : null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }});
          results.push({actionId: action.actionId, resolution: "applied",
            itemIds: [itemRef.id]});
          continue;
        }
        const candidates = new Map(action.candidateBatches.map((item) =>
          [item.itemId, item]));
        if (action.reviewState === "needsReview" &&
            !decision.targetItemId && !decision.batchAllocations) {
          throwInvalidArgument("Action này cần chọn batch và lượng rõ ràng.");
        }
        let allocations: Array<{itemId: string; quantity: number}>;
        if (action.type === "set_quantity") {
          const itemId = decision.targetItemId ?? action.targetItemId;
          if (!itemId || !validNumber(quantity, true) ||
              !candidates.has(itemId)) {
            throwInvalidArgument("Hãy chọn batch và lượng còn lại.");
          }
          allocations = [{itemId, quantity}];
        } else {
          if (!validNumber(quantity) || !unit) {
            throwInvalidArgument("Số lượng hoặc đơn vị của action không hợp lệ.");
          }
          if (decision.targetItemId && decision.batchAllocations) {
            throwInvalidArgument("Chỉ chọn một cách phân bổ batch.");
          }
          allocations = decision.batchAllocations ??
            (decision.targetItemId ? [{itemId: decision.targetItemId,
              quantity}] : allocateFefo(action.candidateBatches, quantity) ?? []);
          const sum = allocations.reduce((total, item) => total + item.quantity, 0);
          if (!allocations.length || Math.abs(sum - quantity) > 0.000001) {
            throwInvalidArgument("Tổng lượng chọn theo batch không khớp.");
          }
        }
        for (const allocation of allocations) {
          const expected = candidates.get(allocation.itemId);
          const item = current.get(allocation.itemId);
          if (!expected || !item || allUsedIds.has(allocation.itemId) ||
              item.status !== "active" || item.name !== expected.name ||
              item.quantity !== expected.quantity ||
              item.unit !== expected.unit || unit !== expected.unit ||
              (item.expirationDate?.toDate?.() ?
                vietnamDate(item.expirationDate.toDate()) : null) !==
                expected.expirationDate ||
              item.updatedAt?.toMillis?.() !== expected.updatedAtMillis ||
              item.createdAt?.toMillis?.() !== expected.createdAtMillis ||
              item.initialQuantity !== expected.initialQuantity ||
              !validNumber(allocation.quantity, action.type === "set_quantity")) {
            throwFailedPrecondition(`Batch ${allocation.itemId} đã thay đổi hoặc không hợp lệ.`);
          }
          allUsedIds.add(allocation.itemId);
          const remaining = action.type === "set_quantity" ?
            allocation.quantity : item.quantity - allocation.quantity;
          if (remaining < 0 || remaining > item.quantity ||
              !validNumber(item.initialQuantity) ||
              item.quantity > item.initialQuantity) {
            throwFailedPrecondition(`Batch ${allocation.itemId} không đủ lượng hoặc thiếu mốc.`);
          }
          updates.set(allocation.itemId, {
            quantity: remaining,
            status: remaining === 0 ?
              (action.type === "discard" ? "discarded" : "consumed") : "active",
            remainingPercentage: Math.round(remaining / item.initialQuantity * 100),
          });
        }
        results.push({actionId: action.actionId, resolution: "applied",
          itemIds: allocations.map((item) => item.itemId)});
      }
      const leavingActive = [...updates.values()]
        .filter((update) => update.status !== "active").length;
      if (foodLimit !== null &&
          activeCount - leavingActive + creations.length > foodLimit) {
        throwResourceExhausted("Gói thành viên đã đạt giới hạn món trong kho.");
      }
      const actionStatus = results.some((item) => item.resolution === "applied") ?
        "applied" : "dismissed";
      const result: ApplyAiResult = {messageId, actionStatus, results};
      for (const [itemId, update] of updates) {
        tx.update(itemRefs.doc(itemId), {...update,
          updatedAt: FieldValue.serverTimestamp()});
      }
      for (const creation of creations) {
        tx.set(itemRefs.doc(creation.itemId), creation.data);
      }
      if (creations.length > 0) {
        tx.update(householdRef, {
          activeItemCount: activeCount + creations.length,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      tx.update(messageRef, {
        actionStatus,
        decisionsHash: hash,
        applyResult: result,
        actions: actions.map((action) => ({...action,
          resolution: results.find((item) => item.actionId === action.actionId)!.resolution})),
      });
      return result;
    });
  }
}

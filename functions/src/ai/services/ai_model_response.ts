import {randomUUID} from "crypto";
import {Type} from "@google/genai";

export interface AssistantInventoryItem {
  ref: string;
  itemId: string;
  name: string;
  quantity: number;
  unit: string;
  expirationDate: string | null;
  isExpired: boolean;
  storageLocationId: string;
  normalizedName: string;
  categoryId: string;
  initialQuantity: number;
  updatedAtMillis: number;
  createdAtMillis: number;
}

export type AiActionType = "consume" | "discard" | "set_quantity" | "add_inventory";

export interface ActionCandidate {
  itemId: string;
  name: string;
  quantity: number;
  initialQuantity: number;
  unit: string;
  expirationDate: string | null;
  updatedAtMillis: number;
  createdAtMillis: number;
}

export interface ValidatedAction {
  actionId: string;
  type: AiActionType;
  name: string;
  quantity?: number;
  unit?: string;
  categoryId?: string;
  storageLocationId?: string;
  targetItemId?: string;
  candidateBatches: ActionCandidate[];
  reviewState: "ready" | "needsReview";
  resolution: "pending" | "applied" | "dismissed" | "expired";
}

export interface ValidatedRecipe {
  title: string;
  usesRefs: string[];
  usedIngredients: string[];
  missingIngredients: string[];
  steps: string[];
  cookingMinutes?: number;
}

export const assistantResponseSchema = {
  type: Type.OBJECT,
  properties: {
    reply: {type: Type.STRING},
    recipes: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          title: {type: Type.STRING},
          usesRefs: {type: Type.ARRAY, items: {type: Type.STRING}},
          missingIngredients: {type: Type.ARRAY, items: {type: Type.STRING}},
          steps: {type: Type.ARRAY, items: {type: Type.STRING}},
          cookingMinutes: {type: Type.INTEGER},
        },
        required: ["title", "usesRefs", "missingIngredients", "steps"],
      },
    },
    actions: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          type: {type: Type.STRING},
          ref: {type: Type.STRING},
          name: {type: Type.STRING},
          quantity: {type: Type.NUMBER},
          unit: {type: Type.STRING},
          categoryId: {type: Type.STRING},
          storageLocationId: {type: Type.STRING},
        },
        required: ["type"],
      },
    },
  },
  required: ["reply", "recipes", "actions"],
};

function shortString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const result = value.trim();
  return result.length > 0 && result.length <= maxLength ? result : null;
}

function shortStrings(value: unknown, maxItems: number, maxLength: number):
  string[] | null {
  if (!Array.isArray(value) || value.length > maxItems) return null;
  const strings = value.map((item) => shortString(item, maxLength));
  return strings.every((item): item is string => item !== null) ?
    strings as string[] : null;
}

export function validateAssistantResponse(
  responseText: string | undefined,
  inventory: AssistantInventoryItem[],
  inventoryTruncated = false
): {reply: string; recipes: ValidatedRecipe[]; actions: ValidatedAction[]} | null {
  if (!responseText || responseText.length > 24000) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(responseText);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const value = parsed as Record<string, unknown>;
  const reply = shortString(value.reply, 4000);
  if (!reply || !Array.isArray(value.recipes) || value.recipes.length > 3 ||
      !Array.isArray(value.actions) || value.actions.length > 10) return null;

  const usable = new Map(inventory
    .filter((item) => !item.isExpired && item.quantity > 0)
    .map((item) => [item.ref, item]));
  const recipes: ValidatedRecipe[] = [];
  for (const candidate of value.recipes) {
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) continue;
    const recipe = candidate as Record<string, unknown>;
    const title = shortString(recipe.title, 120);
    const refs = shortStrings(recipe.usesRefs, 20, 20);
    const missing = shortStrings(recipe.missingIngredients, 20, 100);
    const steps = shortStrings(recipe.steps, 12, 400);
    const minutes = recipe.cookingMinutes;
    if (!title || !refs || !missing || !steps || steps.length === 0 ||
        refs.length !== new Set(refs).size || refs.some((ref) => !usable.has(ref)) ||
        (minutes !== undefined &&
          (!Number.isInteger(minutes) || (minutes as number) < 1 ||
            (minutes as number) > 600))) continue;
    recipes.push({
      title,
      usesRefs: refs.map((ref) => usable.get(ref)!.itemId),
      usedIngredients: refs.map((ref) => usable.get(ref)!.name),
      missingIngredients: missing,
      steps,
      ...(minutes === undefined ? {} : {cookingMinutes: minutes as number}),
    });
  }
  const byRef = new Map(inventory.map((item) => [item.ref, item]));
  const actions: ValidatedAction[] = [];
  for (const raw of value.actions) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) continue;
    const proposed = raw as Record<string, unknown>;
    const type = proposed.type;
    if (type !== "consume" && type !== "discard" &&
        type !== "set_quantity" && type !== "add_inventory") continue;
    const ref = shortString(proposed.ref, 20);
    const linked = ref ? byRef.get(ref) : undefined;
    const name = shortString(proposed.name, 100) ?? linked?.name;
    if (!name) continue;
    const rawQuantity = proposed.quantity;
    const quantity = typeof rawQuantity === "number" &&
      Number.isFinite(rawQuantity) && rawQuantity >= 0 && rawQuantity <= 1000000 ?
      rawQuantity : undefined;
    const unit = shortString(proposed.unit, 30) ?? linked?.unit;
    const storageLocationId = proposed.storageLocationId === "fridge" ||
      proposed.storageLocationId === "freezer" ?
      proposed.storageLocationId : undefined;
    const proposedCategoryId = type === "add_inventory" &&
      typeof proposed.categoryId === "string" &&
      /^[a-zA-Z0-9_-]{1,128}$/.test(proposed.categoryId) ?
      proposed.categoryId : undefined;
    if (type !== "add_inventory" && !linked) continue;
    const candidates = type === "add_inventory" ? [] : inventory
      .filter((item) => item.normalizedName === linked?.normalizedName &&
        item.unit === linked.unit)
      .slice(0, 20)
      .map((item) => ({
        itemId: item.itemId,
        name: item.name,
        quantity: item.quantity,
        initialQuantity: item.initialQuantity,
        unit: item.unit,
        expirationDate: item.expirationDate,
        updatedAtMillis: item.updatedAtMillis,
        createdAtMillis: item.createdAtMillis,
      }));
    const tooManyCandidates = type !== "add_inventory" && inventory
      .filter((item) => item.normalizedName === linked?.normalizedName &&
        item.unit === linked?.unit).length > 20;
    const ready = type !== "add_inventory" && !inventoryTruncated &&
      !tooManyCandidates && candidates.length > 0 &&
      candidates.every((candidate) => candidate.initialQuantity > 0 &&
        candidate.quantity <= candidate.initialQuantity &&
        candidate.createdAtMillis > 0 && candidate.updatedAtMillis > 0) &&
      quantity !== undefined &&
      (type === "set_quantity" ?
        candidates.length === 1 && quantity <= candidates[0].quantity :
        quantity > 0 && candidates.reduce((sum, item) =>
          sum + item.quantity, 0) >= quantity) &&
      (!unit || unit === linked?.unit);
    actions.push({
      actionId: randomUUID(),
      type,
      name,
      ...(quantity === undefined ? {} : {quantity}),
      ...(unit === undefined ? {} : {unit}),
      ...(storageLocationId === undefined ? {} : {storageLocationId}),
      ...((proposedCategoryId ?? linked?.categoryId) ?
        {categoryId: proposedCategoryId ?? linked?.categoryId} : {}),
      ...(type === "set_quantity" && candidates.length === 1 ?
        {targetItemId: candidates[0].itemId} : {}),
      candidateBatches: candidates,
      reviewState: ready ? "ready" : "needsReview",
      resolution: "pending",
    });
  }
  return {reply, recipes, actions};
}

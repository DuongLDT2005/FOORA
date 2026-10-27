import {randomUUID} from "crypto";
import {normalizeFoodName} from "../../utils/string";
import {namesItem} from "./ai_inventory_consume";

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
  /** add_inventory: matched `foods` entry, as in receipt scanning. */
  foodId?: string;
  photoUrl?: string | null;
  /** add_inventory: the user's wording when the catalog name differs. */
  spokenName?: string;
  /** add_inventory: estimated expiry `YYYY-MM-DD` (Vietnam day). */
  expirationDate?: string;
  candidateBatches: ActionCandidate[];
  reviewState: "ready" | "needsReview";
  resolution: "pending" | "applied" | "dismissed" | "expired";
}

export interface ValidatedRecipeIngredient {
  name: string;
  quantity?: number;
  unit?: string;
  /** Inventory item the ingredient comes from; absent when it must be bought. */
  itemId?: string;
  /** Vietnam day `YYYY-MM-DD` the linked item expires, shown next to it. */
  expirationDate?: string;
}

/**
 * A suggested dish: only its ingredients and amounts, no cooking steps.
 * Suggestions never change inventory; the user reports what they cooked
 * afterwards and that message becomes reviewable consume actions.
 */
export interface ValidatedRecipe {
  title: string;
  servings?: number;
  ingredients: ValidatedRecipeIngredient[];
  /** Derived from `ingredients`, kept for older readers of `ai_chats`. */
  usesRefs: string[];
  usedIngredients: string[];
  missingIngredients: string[];
}

function shortString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const result = value.trim();
  return result.length > 0 && result.length <= maxLength ? result : null;
}

/** Units a recipe amount may be converted between, in their base unit. */
const UNIT_FACTORS: Record<string, {group: string; factor: number}> = {
  "g": {group: "mass", factor: 1},
  "gam": {group: "mass", factor: 1},
  "gram": {group: "mass", factor: 1},
  "lạng": {group: "mass", factor: 100},
  "kg": {group: "mass", factor: 1000},
  "ml": {group: "volume", factor: 1},
  "l": {group: "volume", factor: 1000},
  "lít": {group: "volume", factor: 1000},
};

/**
 * Converts a recipe amount into the unit an inventory item is stored in, so
 * it can be compared with the stock and reused by "I cooked this". Returns
 * null when the units cannot be converted (e.g. "quả" and "g").
 * @param {number} quantity Amount in `from`.
 * @param {string} from Unit the model used.
 * @param {string} to Unit of the inventory item.
 * @return {number | null} Amount in `to`, rounded to two decimals.
 */
export function convertRecipeAmount(
  quantity: number,
  from: string,
  to: string
): number | null {
  const source = from.trim().toLocaleLowerCase("vi-VN");
  const target = to.trim().toLocaleLowerCase("vi-VN");
  if (source === target) return quantity;
  const fromUnit = UNIT_FACTORS[source];
  const toUnit = UNIT_FACTORS[target];
  if (!fromUnit || !toUnit || fromUnit.group !== toUnit.group) return null;
  return Math.round(quantity * fromUnit.factor / toUnit.factor * 100) / 100;
}

function validQuantity(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) &&
    value > 0 && value <= 1000000 ? value : undefined;
}

/**
 * Finds the unexpired item an ingredient without a ref names, so food already
 * in the fridge is never listed as something to buy. An exact name wins,
 * then an item not yet used by the dish, nearest expiry first.
 * @param {string} name Ingredient name from the model.
 * @param {Map<string, AssistantInventoryItem>} usable Unexpired items by ref.
 * @param {Set<string>} seenRefs Refs the dish already uses.
 * @return {AssistantInventoryItem | undefined} The item, if the fridge has it.
 */
function usableItemByName(
  name: string,
  usable: Map<string, AssistantInventoryItem>,
  seenRefs: Set<string>
): AssistantInventoryItem | undefined {
  const matches = [...usable.values()]
    .filter((item) => namesItem(name, item.name));
  const wanted = normalizeFoodName(name);
  return matches.find((item) => normalizeFoodName(item.name) === wanted) ??
    matches.find((item) => !seenRefs.has(item.ref)) ?? matches[0];
}

/**
 * Checks one suggested dish. Any ingredient that names an expired or unknown
 * item drops the whole dish, so a suggestion never relies on stock the user
 * should not eat. An ingredient without a ref is linked by name when the
 * fridge has it; only food the fridge lacks stays as "to buy". Amounts of
 * fridge items are converted into the item's unit when possible, and the
 * part above the stock is listed again as "to buy".
 * @param {unknown} candidate Model recipe.
 * @param {Map<string, AssistantInventoryItem>} usable Unexpired items by ref.
 * @return {ValidatedRecipe | null} The dish, or null when invalid.
 */
function validateRecipe(
  candidate: unknown,
  usable: Map<string, AssistantInventoryItem>
): ValidatedRecipe | null {
  if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
    return null;
  }
  const recipe = candidate as Record<string, unknown>;
  const title = shortString(recipe.title, 120);
  const servings = recipe.servings;
  if (!title || !Array.isArray(recipe.ingredients) ||
      recipe.ingredients.length === 0 || recipe.ingredients.length > 15 ||
      (servings !== undefined && (!Number.isInteger(servings) ||
        (servings as number) < 1 || (servings as number) > 20))) return null;
  const ingredients: ValidatedRecipeIngredient[] = [];
  const seenRefs = new Set<string>();
  for (const raw of recipe.ingredients) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
    const ingredient = raw as Record<string, unknown>;
    // An empty ref means "not from the fridge", like a missing one.
    const ref = ingredient.ref === undefined || ingredient.ref === null ||
      ingredient.ref === "" ? null : shortString(ingredient.ref, 20);
    if (ingredient.ref !== undefined && ingredient.ref !== null &&
        ingredient.ref !== "" &&
        (!ref || !usable.has(ref) || seenRefs.has(ref))) return null;
    const spokenName = shortString(ingredient.name, 100);
    const item = ref ? usable.get(ref) :
      spokenName ? usableItemByName(spokenName, usable, seenRefs) : undefined;
    if (item) seenRefs.add(item.ref);
    const name = item?.name ?? spokenName;
    if (!name) return null;
    let quantity = validQuantity(ingredient.quantity);
    let unit = shortString(ingredient.unit, 30) ?? item?.unit;
    const inStock = item && quantity !== undefined && unit !== undefined ?
      convertRecipeAmount(quantity, unit, item.unit) : null;
    if (item && inStock !== null) {
      quantity = inStock;
      unit = item.unit;
    }
    // More than the fridge holds: the stock is used and the rest is bought.
    const shortfall = item && inStock !== null && inStock > item.quantity ?
      Math.round((inStock - item.quantity) * 100) / 100 : 0;
    ingredients.push({
      name,
      ...(quantity === undefined ? {} :
        {quantity: shortfall > 0 ? item!.quantity : quantity}),
      ...(unit === undefined ? {} : {unit}),
      ...(item ? {itemId: item.itemId} : {}),
      ...(item?.expirationDate ? {expirationDate: item.expirationDate} : {}),
    });
    if (shortfall > 0) {
      ingredients.push({name, quantity: shortfall, ...(unit ? {unit} : {})});
    }
  }
  return {
    title,
    ...(servings === undefined ? {} : {servings: servings as number}),
    ingredients,
    usesRefs: ingredients.flatMap((item) => item.itemId ? [item.itemId] : []),
    usedIngredients: ingredients.flatMap((item) =>
      item.itemId ? [item.name] : []),
    missingIngredients: ingredients.flatMap((item) =>
      item.itemId ? [] : [item.name]),
  };
}

/**
 * Links an inventory action whose ref is missing or unknown by its name, but
 * only when the name points to exactly one kind of item (same name and unit),
 * so an ambiguous name is still dropped instead of guessed.
 * @param {unknown} rawName Food name proposed by the model.
 * @param {AssistantInventoryItem[]} inventory Items sent as context.
 * @return {AssistantInventoryItem | undefined} An item of that kind.
 */
function linkByName(
  rawName: unknown,
  inventory: AssistantInventoryItem[]
): AssistantInventoryItem | undefined {
  const name = shortString(rawName, 100);
  if (!name) return undefined;
  const matches = inventory.filter((item) => namesItem(name, item.name));
  const kinds = new Set(matches.map((item) =>
    `${item.normalizedName}|${item.unit}`));
  return kinds.size === 1 ? matches[0] : undefined;
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
    const recipe = validateRecipe(candidate, usable);
    if (recipe) recipes.push(recipe);
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
    const linked = (ref ? byRef.get(ref) : undefined) ??
      (type === "add_inventory" ? undefined :
        linkByName(proposed.name, inventory));
    const name = shortString(proposed.name, 100) ?? linked?.name;
    if (!name) continue;
    const rawQuantity = proposed.quantity;
    // Units are never converted and a missing amount is never read as "all
    // of it" (PLAN_04 §2.1, §3.2): such actions stay in needsReview.
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
      // consume/discard are split over batches by FEFO when applied; only
      // set_quantity targets one batch, and only when it is unambiguous.
      ...(type === "set_quantity" && candidates.length === 1 ?
        {targetItemId: candidates[0].itemId} : {}),
      candidateBatches: candidates,
      reviewState: ready ? "ready" : "needsReview",
      resolution: "pending",
    });
  }
  return {reply, recipes, actions};
}

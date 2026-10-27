import {normalizeFoodName} from "../../utils/string";
import {
  MasterFoodItem,
  findBestMasterFoodMatch,
} from "../../inventory/services/food_matcher";
import {ValidatedAction} from "./ai_model_response";
import {suggestFoodCategoryId} from "./ai_food_category";

/**
 * Links an add_inventory proposal to the `foods` catalog the same way
 * receipt scanning does: a matched food supplies the canonical name, foodId,
 * category, default unit and photo. Without a match the name is kept and the
 * category comes from the name heuristic, then the model's guess.
 * @param {ValidatedAction} action Validated proposal.
 * @param {MasterFoodItem[]} foods Active catalog entries.
 * @return {ValidatedAction} Proposal ready to store (no undefined fields).
 */
export function assignCatalogFood(
  action: ValidatedAction,
  foods: MasterFoodItem[]
): ValidatedAction {
  if (action.type !== "add_inventory") return action;
  const {matchedFood} = findBestMasterFoodMatch(
    normalizeFoodName(action.name), foods);
  const categoryId = matchedFood?.categoryId ??
    suggestFoodCategoryId(action.name) ?? action.categoryId;
  const unit = action.unit?.trim() || matchedFood?.defaultUnit?.trim();
  const storageLocationId = action.storageLocationId ??
    (categoryId === "frozen_foods" ? "freezer" : "fridge");
  return {
    ...action,
    ...(matchedFood ? {
      name: matchedFood.name,
      foodId: matchedFood.id,
      photoUrl: matchedFood.photoUrl ?? null,
      // What the user said, shown when the catalog name differs.
      ...(normalizeFoodName(action.name) !==
        normalizeFoodName(matchedFood.name) ? {spokenName: action.name} : {}),
    } : {}),
    ...(categoryId ? {categoryId} : {}),
    ...(unit ? {unit} : {}),
    storageLocationId,
  };
}

import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService} from "../services/shopping_service";
import {validateImportItems} from "../services/shopping_validation";

interface ImportShoppingItemsPayload {
  householdId: string;
  shoppingListId: string;
  items: unknown;
}

interface ImportShoppingItemsResult {
  addedCount: number;
  itemIds: string[];
}

export const importShoppingItemsToInventory = onCall<Partial<ImportShoppingItemsPayload>>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<ImportShoppingItemsResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, shoppingListId, items} = request.data || {};
      if (typeof householdId !== "string" || !householdId) {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }
      if (typeof shoppingListId !== "string" || !shoppingListId) {
        throwInvalidArgument("Thiếu hoặc sai định dạng shoppingListId.");
      }
      const validated = validateImportItems(items);
      if (!validated.ok) {
        throwInvalidArgument(validated.error);
      }

      const result = await ShoppingService.importShoppingItemsToInventory(
        user.uid, householdId, shoppingListId, validated.value
      );
      return {
        success: true,
        data: result,
        message: `Đã nhập thành công ${result.addedCount} món vào tủ lạnh!`,
      };
    } catch (error) {
      handleFunctionError(error, "importShoppingItemsToInventory");
    }
  }
);

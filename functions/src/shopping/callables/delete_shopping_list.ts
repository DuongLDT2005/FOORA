import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService} from "../services/shopping_service";

interface DeleteShoppingListPayload {
  householdId: string;
  shoppingListId: string;
}

export const deleteShoppingList = onCall<Partial<DeleteShoppingListPayload>>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<{deleted: boolean}>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, shoppingListId} = request.data || {};
      if (typeof householdId !== "string" || !householdId) {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }
      if (typeof shoppingListId !== "string" || !shoppingListId) {
        throwInvalidArgument("Thiếu hoặc sai định dạng shoppingListId.");
      }

      await ShoppingService.deleteShoppingList(user.uid, householdId, shoppingListId);
      return {
        success: true,
        data: {deleted: true},
        message: "Xóa danh sách mua sắm thành công!",
      };
    } catch (error) {
      handleFunctionError(error, "deleteShoppingList");
    }
  }
);

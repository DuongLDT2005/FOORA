import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
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
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<{deleted: boolean}>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const data = request.data || {};

      if (!data.householdId || typeof data.householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      if (!data.shoppingListId || typeof data.shoppingListId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng shoppingListId.");
      }

      logger.info(
        `[deleteShoppingList] User ${user.uid} is safely deleting shopping list ${data.shoppingListId}`
      );

      await ShoppingService.deleteShoppingList(
        user.uid,
        data.householdId,
        data.shoppingListId
      );

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

import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService} from "../services/shopping_service";

interface DeleteShoppingItemPayload {
  householdId: string;
  shoppingListId: string;
  itemId: string;
}

export const deleteShoppingItem = onCall<Partial<DeleteShoppingItemPayload>>(
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

      if (!data.itemId || typeof data.itemId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng itemId.");
      }

      logger.info(
        `[deleteShoppingItem] User ${user.uid} is deleting item ${data.itemId} from list ${data.shoppingListId}`
      );

      await ShoppingService.deleteShoppingItem(
        user.uid,
        data.householdId,
        data.shoppingListId,
        data.itemId
      );

      return {
        success: true,
        data: {deleted: true},
        message: "Xóa món khỏi danh sách thành công!",
      };
    } catch (error) {
      handleFunctionError(error, "deleteShoppingItem");
    }
  }
);

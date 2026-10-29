import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService, AddShoppingItemsBatchInput} from "../services/shopping_service";

interface AddShoppingItemsBatchResult {
  count: number;
}

export const addShoppingItemsBatch = onCall<Partial<AddShoppingItemsBatchInput>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<AddShoppingItemsBatchResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const data = request.data || {};

      if (!data.householdId || typeof data.householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      if (!data.shoppingListId || typeof data.shoppingListId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng shoppingListId.");
      }

      if (!Array.isArray(data.items) || data.items.length === 0) {
        throwInvalidArgument("Danh sách món cần thêm không được rỗng.");
      }

      logger.info(
        `[addShoppingItemsBatch] User ${user.uid} is adding ${data.items.length} items to list ${data.shoppingListId}`
      );

      const result = await ShoppingService.addShoppingItemsBatch(user.uid, {
        householdId: data.householdId,
        shoppingListId: data.shoppingListId,
        items: data.items,
      });

      return {
        success: true,
        data: result,
        message: `Đã thêm ${result.count} món vào danh sách mua sắm!`,
      };
    } catch (error) {
      handleFunctionError(error, "addShoppingItemsBatch");
    }
  }
);

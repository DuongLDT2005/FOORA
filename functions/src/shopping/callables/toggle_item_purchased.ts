import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService} from "../services/shopping_service";

interface ToggleItemPurchasedPayload {
  householdId: string;
  shoppingListId: string;
  itemId: string;
  targetStatus: boolean;
}

export const toggleShoppingItemPurchased = onCall<Partial<ToggleItemPurchasedPayload>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<{isPurchased: boolean}>> => {
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

      if (typeof data.targetStatus !== "boolean") {
        throwInvalidArgument("Trạng thái targetStatus phải là boolean.");
      }

      logger.info(
        `[toggleShoppingItemPurchased] User ${user.uid} is toggling item ${data.itemId} to ${data.targetStatus}`
      );

      const result = await ShoppingService.toggleShoppingItemPurchased(
        user.uid,
        data.householdId,
        data.shoppingListId,
        data.itemId,
        data.targetStatus
      );

      return {
        success: true,
        data: {isPurchased: result.isPurchased},
        message: result.isPurchased ?
          "Đã đánh dấu đã mua!" :
          "Đã chuyển về chưa mua!",
      };
    } catch (error) {
      handleFunctionError(error, "toggleShoppingItemPurchased");
    }
  }
);

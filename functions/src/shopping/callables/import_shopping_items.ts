import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService, ImportShoppingItemInput} from "../services/shopping_service";

interface ImportShoppingItemsPayload {
  householdId: string;
  shoppingListId: string;
  items: ImportShoppingItemInput[];
}

interface ImportShoppingItemsResult {
  addedCount: number;
  itemIds: string[];
}

export const importShoppingItemsToInventory = onCall<Partial<ImportShoppingItemsPayload>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<ImportShoppingItemsResult>> => {
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
        throwInvalidArgument("Danh sách thực phẩm cần nhập kho không được rỗng.");
      }

      logger.info(
        `[importShoppingItemsToInventory] User ${user.uid} is importing ${data.items.length} items from list ${data.shoppingListId} to household ${data.householdId}`
      );

      const result = await ShoppingService.importShoppingItemsToInventory(
        user.uid,
        data.householdId,
        data.shoppingListId,
        data.items
      );

      return {
        success: true,
        data: {
          addedCount: result.addedCount,
          itemIds: result.itemIds,
        },
        message: `Đã nhập thành công ${result.addedCount} món vào tủ lạnh!`,
      };
    } catch (error) {
      handleFunctionError(error, "importShoppingItemsToInventory");
    }
  }
);

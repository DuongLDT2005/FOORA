import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingService, AddShoppingItemInput} from "../services/shopping_service";

interface AddShoppingItemResult {
  itemId: string;
  merged: boolean;
}

export const addShoppingItem = onCall<Partial<AddShoppingItemInput>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<AddShoppingItemResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const data = request.data || {};

      if (!data.householdId || typeof data.householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      if (!data.shoppingListId || typeof data.shoppingListId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng shoppingListId.");
      }

      if (!data.name || typeof data.name !== "string" || !data.name.trim()) {
        throwInvalidArgument("Tên thực phẩm không được để trống.");
      }

      if (typeof data.quantity !== "number" || data.quantity <= 0) {
        throwInvalidArgument("Số lượng phải là số dương lớn hơn 0.");
      }

      if (!data.unit || typeof data.unit !== "string" || !data.unit.trim()) {
        throwInvalidArgument("Đơn vị tính không được để trống.");
      }

      logger.info(
        `[addShoppingItem] User ${user.uid} is adding item "${data.name}" to list ${data.shoppingListId}`
      );

      const result = await ShoppingService.addShoppingItem(user.uid, {
        householdId: data.householdId,
        shoppingListId: data.shoppingListId,
        name: data.name,
        categoryId: data.categoryId || "other",
        quantity: data.quantity,
        unit: data.unit,
        foodId: data.foodId || null,
        note: data.note || null,
        photoUrl: data.photoUrl || null,
        source: data.source || "manual",
        mergeConfirmed: Boolean(data.mergeConfirmed),
      });

      return {
        success: true,
        data: result,
        message: result.merged ?
          "Đã cộng dồn số lượng vào món có sẵn!" :
          "Thêm món vào danh sách thành công!",
      };
    } catch (error) {
      handleFunctionError(error, "addShoppingItem");
    }
  }
);

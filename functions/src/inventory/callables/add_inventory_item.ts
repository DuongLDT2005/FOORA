import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {
  InventoryService,
  AddInventoryItemInput,
} from "../services/inventory_service";

interface AddInventoryItemResult {
  itemId: string;
  expirationDate: string;
}

/**
 * Callable Function: addInventoryItem
 * Adds a new food item into household inventory with atomic limit check and expiration calculation.
 */
export const addInventoryItem = onCall<Partial<AddInventoryItemInput>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<AddInventoryItemResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const data = request.data || {};

      if (!data.householdId || typeof data.householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      if (!data.name || typeof data.name !== "string" || !data.name.trim()) {
        throwInvalidArgument("Tên thực phẩm không được để trống.");
      }

      if (!data.categoryId || typeof data.categoryId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng categoryId.");
      }

      if (typeof data.quantity !== "number" || data.quantity <= 0) {
        throwInvalidArgument("Số lượng phải là số dương lớn hơn 0.");
      }

      if (!data.unit || typeof data.unit !== "string" || !data.unit.trim()) {
        throwInvalidArgument("Đơn vị tính không được để trống.");
      }

      if (!data.storageLocationId || typeof data.storageLocationId !== "string") {
        throwInvalidArgument("Thiếu vị trí bảo quản (storageLocationId).");
      }

      logger.info(
        `[addInventoryItem] User ${user.uid} is adding item "${data.name}" ` +
        `to household ${data.householdId}`
      );

      const result = await InventoryService.addInventoryItemWithLimitCheck(
        user.uid,
        user.membershipId,
        {
          householdId: data.householdId,
          name: data.name,
          foodId: data.foodId || null,
          categoryId: data.categoryId,
          quantity: data.quantity,
          unit: data.unit,
          storageLocationId: data.storageLocationId,
          purchaseDate: data.purchaseDate || new Date(),
          expirationDate: data.expirationDate || null,
          photoUrl: data.photoUrl || null,
          source: data.source || "manual",
        }
      );

      return {
        success: true,
        data: {
          itemId: result.itemId,
          expirationDate: result.expirationDate.toISOString(),
        },
        message: "Thêm thực phẩm vào tủ lạnh thành công!",
      };
    } catch (error) {
      handleFunctionError(error, "addInventoryItem");
    }
  }
);


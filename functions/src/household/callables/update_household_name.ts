import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {HouseholdService} from "../services/household_service";

interface UpdateHouseholdNameInput {
  householdId: string;
  name: string;
}

export const updateHouseholdName = onCall<UpdateHouseholdNameInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<void>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, name} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }
      if (!name || typeof name !== "string" || !name.trim()) {
        throwInvalidArgument("Tên gia đình không được để trống.");
      }

      await HouseholdService.updateHouseholdName(user.uid, householdId, name);

      return {
        success: true,
        message: "Cập nhật tên gia đình thành công.",
      };
    } catch (error) {
      handleFunctionError(error, "updateHouseholdName");
    }
  }
);

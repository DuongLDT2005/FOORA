import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {HouseholdService} from "../services/household_service";

interface SwitchHouseholdInput {
  householdId: string;
}

export const switchHousehold = onCall<SwitchHouseholdInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<void>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }

      await HouseholdService.switchHousehold(user.uid, householdId);

      return {
        success: true,
        message: "Chuyển gia đình hoạt động thành công.",
      };
    } catch (error) {
      handleFunctionError(error, "switchHousehold");
    }
  }
);

import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {HouseholdService} from "../services/household_service";

interface LeaveHouseholdInput {
  householdId: string;
}

export const leaveHousehold = onCall<LeaveHouseholdInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<void>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }

      await HouseholdService.leaveHousehold(user.uid, householdId);

      return {
        success: true,
        message: "Bạn đã rời khỏi gia đình thành công.",
      };
    } catch (error) {
      handleFunctionError(error, "leaveHousehold");
    }
  }
);

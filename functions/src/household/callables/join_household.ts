import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {HouseholdService} from "../services/household_service";

interface JoinHouseholdInput {
  code: string;
}

export const joinHousehold = onCall<JoinHouseholdInput>(
  {region: REGION, maxInstances: 10},
  async (
    request
  ): Promise<ApiResponse<{householdId: string; householdName: string}>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {code} = request.data || {};

      if (!code || typeof code !== "string") {
        throwInvalidArgument("Mã lời mời không được để trống.");
      }

      const result = await HouseholdService.joinHousehold(user.uid, code);

      return {
        success: true,
        data: result,
        message: `Chào mừng bạn đã gia nhập "${result.householdName}"!`,
      };
    } catch (error) {
      handleFunctionError(error, "joinHousehold");
    }
  }
);

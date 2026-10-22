import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {
  HouseholdMemberInfo,
  HouseholdService,
} from "../services/household_service";

interface GetHouseholdMembersInput {
  householdId: string;
}

export const getHouseholdMembers = onCall<GetHouseholdMembersInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<HouseholdMemberInfo[]>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }

      const result = await HouseholdService.getHouseholdMembers(
        user.uid,
        householdId
      );

      return {
        success: true,
        data: result,
      };
    } catch (error) {
      handleFunctionError(error, "getHouseholdMembers");
    }
  }
);

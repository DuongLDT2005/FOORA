import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {
  HouseholdInvitationResult,
  HouseholdService,
} from "../services/household_service";

interface GetActiveInvitationInput {
  householdId: string;
}

export const getActiveHouseholdInvitation = onCall<GetActiveInvitationInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<HouseholdInvitationResult | null>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }

      const result = await HouseholdService.getActiveInvitation(
        user.uid,
        householdId
      );

      return {
        success: true,
        data: result,
      };
    } catch (error) {
      handleFunctionError(error, "getActiveHouseholdInvitation");
    }
  }
);

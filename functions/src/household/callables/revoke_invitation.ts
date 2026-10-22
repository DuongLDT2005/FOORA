import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {HouseholdService} from "../services/household_service";

interface RevokeInvitationInput {
  householdId: string;
  invitationId: string;
}

export const revokeHouseholdInvitation = onCall<RevokeInvitationInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<void>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, invitationId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }
      if (!invitationId || typeof invitationId !== "string") {
        throwInvalidArgument("Thiếu invitationId.");
      }

      await HouseholdService.revokeInvitation(user.uid, householdId, invitationId);

      return {
        success: true,
        message: "Thu hồi mã lời mời thành công.",
      };
    } catch (error) {
      handleFunctionError(error, "revokeHouseholdInvitation");
    }
  }
);

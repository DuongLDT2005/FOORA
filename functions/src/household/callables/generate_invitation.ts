import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {
  HouseholdInvitationResult,
  HouseholdService,
} from "../services/household_service";

interface GenerateInvitationInput {
  householdId: string;
}

export const generateHouseholdInvitation = onCall<GenerateInvitationInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<HouseholdInvitationResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      // Lifetime is fixed server-side (7 days); clients cannot extend it.
      const result = await HouseholdService.createInvitation(
        user.uid,
        householdId
      );

      return {
        success: true,
        data: result,
        message: "Tạo mã lời mời tham gia gia đình thành công!",
      };
    } catch (error) {
      handleFunctionError(error, "generateHouseholdInvitation");
    }
  }
);

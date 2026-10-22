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
  expiresInDays?: number;
}

export const generateHouseholdInvitation = onCall<GenerateInvitationInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<HouseholdInvitationResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, expiresInDays} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      const result = await HouseholdService.createInvitation(
        user.uid,
        householdId,
        expiresInDays ?? 7
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

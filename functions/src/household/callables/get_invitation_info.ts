import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {
  HouseholdInvitationPreview,
  HouseholdService,
} from "../services/household_service";

interface GetInvitationInfoInput {
  code: string;
}

export const getHouseholdInvitationInfo = onCall<GetInvitationInfoInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<HouseholdInvitationPreview>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {code} = request.data || {};

      if (!code || typeof code !== "string") {
        throwInvalidArgument("Mã lời mời không được để trống.");
      }

      const result = await HouseholdService.getInvitationInfo(user.uid, code);

      return {
        success: true,
        data: result,
      };
    } catch (error) {
      handleFunctionError(error, "getHouseholdInvitationInfo");
    }
  }
);

import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {HouseholdService} from "../services/household_service";

interface RemoveMemberInput {
  householdId: string;
  memberUserId: string;
}

export const removeHouseholdMember = onCall<RemoveMemberInput>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<void>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {householdId, memberUserId} = request.data || {};

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu householdId.");
      }
      if (!memberUserId || typeof memberUserId !== "string") {
        throwInvalidArgument("Thiếu memberUserId.");
      }

      await HouseholdService.removeMember(user.uid, householdId, memberUserId);

      return {
        success: true,
        message: "Đã xóa thành viên khỏi gia đình thành công.",
      };
    } catch (error) {
      handleFunctionError(error, "removeHouseholdMember");
    }
  }
);

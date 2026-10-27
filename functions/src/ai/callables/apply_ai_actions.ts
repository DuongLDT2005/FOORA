import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {AiActionService, AiDecision, ApplyAiResult} from
  "../services/ai_action_service";

export const applyAiActions = onCall<Partial<{
  messageId: string; decisions: AiDecision[]
}>>(
  {region: REGION, timeoutSeconds: 60},
  async (request): Promise<ApiResponse<ApplyAiResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {messageId, decisions} = request.data || {};
      // Shape only; the service validates every decision field.
      if (typeof messageId !== "string" || !Array.isArray(decisions)) {
        throwInvalidArgument("Danh sách xác nhận AI không hợp lệ.");
      }
      const data = await AiActionService.apply(user, messageId, decisions);
      return {success: true, data};
    } catch (error) {
      handleFunctionError(error, "applyAiActions");
    }
  }
);

import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError} from "../../utils/errors";
import {AiActionService, AiDecision, ApplyAiResult} from
  "../services/ai_action_service";

export const applyAiActions = onCall<{
  messageId: string; decisions: AiDecision[]
}>(
  {region: REGION, timeoutSeconds: 60},
  async (request): Promise<ApiResponse<ApplyAiResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const data = await AiActionService.apply(user,
        request.data?.messageId, request.data?.decisions);
      return {success: true, data};
    } catch (error) {
      handleFunctionError(error, "applyAiActions");
    }
  }
);

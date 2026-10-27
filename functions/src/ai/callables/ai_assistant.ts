import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {AiAssistantInput, AiAssistantResult, AiAssistantService} from
  "../services/ai_assistant_service";

// Same Gemini key as receipt scanning.
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const aiAssistant = onCall<Partial<AiAssistantInput>>(
  // One warm instance removes the cold start from the first question.
  {region: REGION, timeoutSeconds: 60, minInstances: 0, secrets: [geminiApiKey]},
  async (request): Promise<ApiResponse<AiAssistantResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {requestId, sessionId, householdId, message, inputMode} =
        request.data || {};
      if (typeof requestId !== "string" || !UUID_V4.test(requestId) ||
          typeof sessionId !== "string" || !UUID_V4.test(sessionId) ||
          typeof householdId !== "string" || householdId.length > 128 ||
          typeof message !== "string" || !message.trim() ||
          message.trim().length > 1000 ||
          (inputMode !== "text" && inputMode !== "voice")) {
        throwInvalidArgument("Câu hỏi hoặc thông tin phiên không hợp lệ.");
      }
      const data = await AiAssistantService.send(user, {
        requestId, sessionId, householdId, message: message.trim(), inputMode,
      }, geminiApiKey.value());
      return {success: true, data};
    } catch (error) {
      handleFunctionError(error, "aiAssistant");
    }
  }
);

import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {AiAssistantService, AiAssistantResult} from "../services/ai_assistant_service";

const geminiApiKey = defineSecret("GEMINI_API_KEY");

interface AiAssistantInput {
  requestId: string;
  householdId: string;
  message: string;
  inputMode: "text" | "voice";
}

export const aiAssistant = onCall<Partial<AiAssistantInput>>(
  {region: REGION, timeoutSeconds: 90, secrets: [geminiApiKey]},
  async (request): Promise<ApiResponse<AiAssistantResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {requestId, householdId, message, inputMode} = request.data || {};
      if (typeof requestId !== "string" ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId) ||
          typeof householdId !== "string" || householdId.length > 128 ||
          typeof message !== "string" || !message.trim() ||
          message.trim().length > 1000 ||
          (inputMode !== "text" && inputMode !== "voice")) {
        throwInvalidArgument("Câu hỏi hoặc thông tin phiên không hợp lệ.");
      }
      const data = await AiAssistantService.send(user, {
        requestId, householdId, message: message.trim(), inputMode,
      }, geminiApiKey.value());
      return {success: true, data};
    } catch (error) {
      handleFunctionError(error, "aiAssistant");
    }
  }
);

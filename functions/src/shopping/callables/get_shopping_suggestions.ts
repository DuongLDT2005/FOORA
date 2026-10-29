import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ShoppingSuggestion} from "../services/purchase_frequency";
import {ShoppingService} from "../services/shopping_service";

interface GetShoppingSuggestionsPayload {
  householdId: string;
}

/**
 * "Frequently bought" suggestions. Read-only and does not use AI quota.
 */
export const getShoppingSuggestions = onCall<Partial<GetShoppingSuggestionsPayload>>(
  {region: REGION, maxInstances: 10},
  async (request): Promise<ApiResponse<{suggestions: ShoppingSuggestion[]}>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const householdId = request.data?.householdId;
      if (typeof householdId !== "string" || !householdId) {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      const suggestions = await ShoppingService.getSuggestions(user.uid, householdId);
      return {success: true, data: {suggestions}};
    } catch (error) {
      handleFunctionError(error, "getShoppingSuggestions");
    }
  }
);

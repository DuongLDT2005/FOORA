import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {
  payosApiKey,
  payosChecksumKey,
  payosClientId,
} from "../config";
import {PayosClient} from "../services/payos_client";
import {PaymentService} from "../services/payment_service";
import {
  CreatePaymentOrderInput,
  PaymentOrderResult,
} from "../types/payment_types";

export const createCasPaymentOrder = onCall<Partial<CreatePaymentOrderInput>>(
  {
    region: REGION,
    secrets: [payosClientId, payosApiKey, payosChecksumKey],
  },
  async (request): Promise<ApiResponse<PaymentOrderResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const membershipId = request.data?.membershipId;
      if (typeof membershipId !== "string") {
        throwInvalidArgument("membershipId is required.");
      }
      const data = await new PaymentService(new PayosClient())
        .createOrder(user, membershipId);
      return {success: true, data};
    } catch (error) {
      handleFunctionError(error, "createCasPaymentOrder");
    }
  }
);

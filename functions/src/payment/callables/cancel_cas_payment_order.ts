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

export const cancelCasPaymentOrder = onCall<{paymentId?: string}>(
  {
    region: REGION,
    secrets: [payosClientId, payosApiKey, payosChecksumKey],
  },
  async (request): Promise<ApiResponse<{paymentId: string}>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const paymentId = request.data?.paymentId;
      if (typeof paymentId !== "string" || !paymentId) {
        throwInvalidArgument("paymentId is required.");
      }
      await new PaymentService(new PayosClient())
        .cancelOrder(user.uid, paymentId);
      return {success: true, data: {paymentId}};
    } catch (error) {
      handleFunctionError(error, "cancelCasPaymentOrder");
    }
  }
);

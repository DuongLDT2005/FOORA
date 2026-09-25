import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {REGION} from "../../config/firebase";
import {
  payosApiKey,
  payosChecksumKey,
  payosClientId,
} from "../config";
import {PayosClient} from "../services/payos_client";
import {verifyAndParsePayosWebhook} from "../services/payos_webhook";
import {PaymentService} from "../services/payment_service";

export const casTransactionsWebhook = onRequest(
  {
    region: REGION,
    secrets: [payosClientId, payosApiKey, payosChecksumKey],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({success: false});
      return;
    }
    if (!request.is("application/json")) {
      response.status(415).json({success: false});
      return;
    }

    let transaction;
    try {
      transaction = await verifyAndParsePayosWebhook(request.body);
    } catch {
      response.status(401).json({success: false});
      return;
    }
    if (!transaction) {
      response.status(400).json({success: false});
      return;
    }

    try {
      const status = await new PaymentService(new PayosClient())
        .reconcile(transaction);
      logger.info("payOS transaction reconciled", {
        providerTransactionId: transaction.providerTransactionId,
        status,
      });
      response.status(200).json({success: true, status});
    } catch (error) {
      logger.error("payOS webhook reconciliation failed", {error});
      response.status(500).json({success: false});
    }
  }
);

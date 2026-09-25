import {PayOS} from "@payos/node";
import {HttpsError} from "firebase-functions/v2/https";
import {
  payosApiKey,
  payosBaseUrl,
  payosCancelUrl,
  payosChecksumKey,
  payosClientId,
  payosReturnUrl,
} from "../config";
import {
  CreateProviderOrderInput,
  PaymentProviderClient,
  PaymentProviderOrder,
} from "../types/payment_types";

interface PayosPaymentRequests {
  create(data: {
    orderCode: number;
    amount: number;
    description: string;
    cancelUrl: string;
    returnUrl: string;
    expiredAt: number;
  }): Promise<{
    paymentLinkId: string;
    qrCode: string;
    accountNumber: string;
    description: string;
  }>;
  cancel(paymentLinkId: string, reason?: string): Promise<unknown>;
}

interface PayosSdk {
  paymentRequests: PayosPaymentRequests;
}

export class PayosClient implements PaymentProviderClient {
  constructor(private readonly injectedSdk?: PayosSdk) {}

  async createQrPay(
    input: CreateProviderOrderInput
  ): Promise<PaymentProviderOrder> {
    const orderCode = Number(input.referenceNumber);
    if (!Number.isSafeInteger(orderCode) || orderCode <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "payOS orderCode must be a positive safe integer."
      );
    }

    try {
      const order = await this.sdk().paymentRequests.create({
        orderCode,
        amount: input.amount,
        description: input.description,
        cancelUrl: payosCancelUrl.value(),
        returnUrl: payosReturnUrl.value(),
        expiredAt: Math.floor(input.expiresAt.getTime() / 1000),
      });
      if (!order.paymentLinkId || !order.qrCode) {
        throw new Error("payOS response is missing payment link data.");
      }
      return {
        providerRequestId: order.paymentLinkId,
        qrCode: order.qrCode,
        virtualAccountNumber: order.accountNumber,
        description: order.description,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("unavailable", "payOS payment creation failed.");
    }
  }

  async cancelPaymentOrder(providerRequestId: string): Promise<void> {
    try {
      await this.sdk().paymentRequests.cancel(
        providerRequestId,
        "User cancelled the FOORA payment"
      );
    } catch {
      throw new HttpsError("unavailable", "payOS payment cancellation failed.");
    }
  }

  private sdk(): PayosSdk {
    return this.injectedSdk ?? new PayOS({
      clientId: payosClientId.value(),
      apiKey: payosApiKey.value(),
      checksumKey: payosChecksumKey.value(),
      baseURL: payosBaseUrl.value(),
      timeout: 10000,
      maxRetries: 1,
      logLevel: "off",
    });
  }
}

import {PaymentStatus} from "../../types";

export interface CreatePaymentOrderInput {
  membershipId: string;
}

export interface PaymentOrderResult {
  paymentId: string;
  membershipId: string;
  amount: number;
  currency: string;
  status: PaymentStatus;
  referenceNumber: string;
  qrCode: string;
  virtualAccountNumber?: string;
  description: string;
  expiresAt: string;
}

export interface CreateProviderOrderInput {
  amount: number;
  referenceNumber: string;
  description: string;
  expiresAt: Date;
}

export interface PaymentProviderOrder {
  providerRequestId: string;
  qrCode: string;
  virtualAccountNumber?: string;
  description?: string;
}

export interface PaymentProviderClient {
  createQrPay(
    input: CreateProviderOrderInput
  ): Promise<PaymentProviderOrder>;
  cancelPaymentOrder?(providerRequestId: string): Promise<void>;
}

export interface ProviderWebhookTransaction {
  providerTransactionId: string;
  amount: number;
  description: string;
  referenceNumber?: string;
  transactionDate: Date;
}

export type CasQrPayOrder = PaymentProviderOrder;
export type CasWebhookTransaction = ProviderWebhookTransaction;

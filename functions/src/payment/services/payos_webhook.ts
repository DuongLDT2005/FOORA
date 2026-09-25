import {PayOS, Webhook, WebhookData} from "@payos/node";
import {
  payosApiKey,
  payosBaseUrl,
  payosChecksumKey,
  payosClientId,
} from "../config";
import {ProviderWebhookTransaction} from "../types/payment_types";

interface PayosWebhookVerifier {
  webhooks: {
    verify(payload: Webhook): Promise<WebhookData>;
  };
}

function parsePayosDate(value: string): Date | null {
  const normalized = value.includes("T") ? value : value.replace(" ", "T");
  const hasTimeZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(normalized);
  const parsed = new Date(hasTimeZone ? normalized : `${normalized}+07:00`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function mapPayosWebhookData(
  data: WebhookData
): ProviderWebhookTransaction | null {
  const transactionDate = parsePayosDate(data.transactionDateTime);
  if (data.code !== "00" || !Number.isFinite(data.amount) ||
      data.amount <= 0 || !transactionDate || !data.reference) {
    return null;
  }

  return {
    providerTransactionId: data.reference,
    amount: data.amount,
    description: data.description,
    referenceNumber: String(data.orderCode),
    transactionDate,
  };
}

export async function verifyAndParsePayosWebhook(
  payload: unknown,
  injectedSdk?: PayosWebhookVerifier
): Promise<ProviderWebhookTransaction | null> {
  const sdk = injectedSdk ?? new PayOS({
    clientId: payosClientId.value(),
    apiKey: payosApiKey.value(),
    checksumKey: payosChecksumKey.value(),
    baseURL: payosBaseUrl.value(),
    timeout: 10000,
    maxRetries: 1,
    logLevel: "off",
  });
  const data = await sdk.webhooks.verify(payload as Webhook);
  return mapPayosWebhookData(data);
}

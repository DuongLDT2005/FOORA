import {defineSecret, defineString} from "firebase-functions/params";

export const payosClientId = defineSecret("PAYOS_CLIENT_ID");
export const payosApiKey = defineSecret("PAYOS_API_KEY");
export const payosChecksumKey = defineSecret("PAYOS_CHECKSUM_KEY");

export const payosBaseUrl = defineString("PAYOS_BASE_URL", {
  default: "https://api-merchant.payos.vn",
});

export const payosReturnUrl = defineString("PAYOS_RETURN_URL", {
  default: "https://foora.app/payment/success",
});

export const payosCancelUrl = defineString("PAYOS_CANCEL_URL", {
  default: "https://foora.app/payment/cancel",
});

export const paymentExpiryMinutes = defineString("PAYMENT_EXPIRY_MINUTES", {
  default: "15",
});

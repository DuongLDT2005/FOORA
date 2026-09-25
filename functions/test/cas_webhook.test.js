const assert = require("node:assert/strict");
const test = require("node:test");
const {PayOS} = require("@payos/node");
const {
  verifyAndParsePayosWebhook,
} = require("../lib/payment/services/payos_webhook.js");

const checksumKey =
  "1a54716c8f0efb2744fb28b6e38b25da7f67a925d98bc1c18bd8faaecadd7675";
const data = {
  orderCode: 123456789012,
  amount: 29000,
  description: "FOORA 123456789012",
  accountNumber: "12345678",
  reference: "TF230204212323",
  transactionDateTime: "2026-09-25 17:00:00",
  currency: "VND",
  paymentLinkId: "124c33293c43417ab7879e14c8d9eb18",
  code: "00",
  desc: "Success",
  counterAccountBankId: "",
  counterAccountBankName: "",
  counterAccountName: "",
  counterAccountNumber: "",
  virtualAccountName: "",
  virtualAccountNumber: "",
};

function createSdk() {
  return new PayOS({
    clientId: "test-client",
    apiKey: "test-api-key",
    checksumKey,
    logLevel: "off",
  });
}

test("verifies and maps a payOS payment webhook", async () => {
  const sdk = createSdk();
  const signature = await sdk.crypto.createSignatureFromObj(data, checksumKey);
  const transaction = await verifyAndParsePayosWebhook(
    {code: "00", desc: "success", success: true, data, signature},
    sdk
  );

  assert.ok(transaction);
  assert.equal(transaction.providerTransactionId, "TF230204212323");
  assert.equal(transaction.referenceNumber, "123456789012");
  assert.equal(transaction.amount, 29000);
  assert.equal(
    transaction.transactionDate.toISOString(),
    "2026-09-25T10:00:00.000Z"
  );
});

test("rejects a payOS webhook with an invalid signature", async () => {
  const sdk = createSdk();
  await assert.rejects(
    verifyAndParsePayosWebhook(
      {
        code: "00",
        desc: "success",
        success: true,
        data,
        signature: "invalid",
      },
      sdk
    )
  );
});

test("rejects non-success payOS transaction data", async () => {
  const sdk = createSdk();
  const failedData = {...data, code: "01"};
  const signature = await sdk.crypto.createSignatureFromObj(
    failedData,
    checksumKey
  );
  const transaction = await verifyAndParsePayosWebhook(
    {
      code: "00",
      desc: "success",
      success: true,
      data: failedData,
      signature,
    },
    sdk
  );
  assert.equal(transaction, null);
});

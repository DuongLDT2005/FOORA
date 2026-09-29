const assert = require("node:assert/strict");
const test = require("node:test");

process.env.PAYOS_RETURN_URL = "https://foora.app/payment/success";
process.env.PAYOS_CANCEL_URL = "https://foora.app/payment/cancel";

const {PayosClient} = require("../lib/payment/services/payos_client.js");

test("maps a FOORA order to the payOS payment request contract", async () => {
  let capturedCreate;
  const sdk = {
    paymentRequests: {
      create: async (data) => {
        capturedCreate = data;
        return {
          paymentLinkId: "payos-link-123",
          qrCode: "000201010212...",
          accountNumber: "113366668888",
          description: data.description,
        };
      },
      cancel: async () => ({}),
    },
  };
  const client = new PayosClient(sdk);
  const expiresAt = new Date("2026-09-25T10:15:00.000Z");

  const order = await client.createQrPay({
    amount: 29000,
    referenceNumber: "123456789012",
    description: "FOORA 123456789012",
    expiresAt,
  });

  assert.deepEqual(capturedCreate, {
    orderCode: 123456789012,
    amount: 29000,
    description: "FOORA 123456789012",
    cancelUrl: "https://foora.app/payment/cancel",
    returnUrl: "https://foora.app/payment/success",
    expiredAt: 1790331300,
  });
  assert.deepEqual(order, {
    providerRequestId: "payos-link-123",
    qrCode: "000201010212...",
    virtualAccountNumber: "113366668888",
    description: "FOORA 123456789012",
  });
});

test("cancels the payOS payment link at the provider", async () => {
  let cancelledId;
  const sdk = {
    paymentRequests: {
      create: async () => {
        throw new Error("not used");
      },
      cancel: async (id) => {
        cancelledId = id;
        return {};
      },
    },
  };

  await new PayosClient(sdk).cancelPaymentOrder("payos-link-123");
  assert.equal(cancelledId, "payos-link-123");
});

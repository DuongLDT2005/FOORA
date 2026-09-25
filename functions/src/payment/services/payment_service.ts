import {randomBytes} from "node:crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {AuthenticatedUser, PaymentStatus} from "../../types";
import {throwInvalidArgument, throwNotFound} from "../../utils/errors";
import {paymentExpiryMinutes} from "../config";
import {
  PaymentOrderResult,
  PaymentProviderClient,
  ProviderWebhookTransaction,
} from "../types/payment_types";

const PROVIDER = "payos";

function createReferenceNumber(): string {
  const value = randomBytes(6).readUIntBE(0, 6) % 900000000000;
  return String(100000000000 + value);
}

function positiveInteger(value: string, fallback: number): number {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export class PaymentService {
  constructor(private readonly paymentClient: PaymentProviderClient) {}

  async createOrder(
    user: AuthenticatedUser,
    membershipId: string
  ): Promise<PaymentOrderResult> {
    if (!membershipId || membershipId !== "premium") {
      throwInvalidArgument("Only the Premium membership can be purchased.");
    }

    const membership = await db.collection(Collections.MEMBERSHIPS)
      .doc(membershipId).get();
    if (!membership.exists) throwNotFound("Membership plan not found.");

    const membershipData = membership.data() ?? {};
    const amount = Number(membershipData.price);
    const durationDays = Number(membershipData.durationDays);
    if (membershipData.isActive === false || !Number.isFinite(amount) ||
        amount <= 0 || !Number.isInteger(durationDays) || durationDays <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Membership is not purchasable."
      );
    }

    const payments = db.collection(Collections.USERS).doc(user.uid)
      .collection(Collections.PAYMENTS);
    const now = new Date();
    const paymentRef = payments.doc();
    const referenceNumber = createReferenceNumber();
    const expiresAt = new Date(
      now.getTime() +
      positiveInteger(paymentExpiryMinutes.value(), 15) * 60000
    );
    const description = `FOORA ${referenceNumber}`;
    const referenceRef = db.collection(Collections.PAYMENT_REFERENCES)
      .doc(referenceNumber);
    const lockRef = db.collection(Collections.PAYMENT_ORDER_LOCKS)
      .doc(`${user.uid}_${membershipId}`);

    const setup = await db.runTransaction(async (firestoreTransaction) => {
      const lock = await firestoreTransaction.get(lockRef);
      const lockedPaymentId = lock.data()?.paymentId;
      const lockedPayment = typeof lockedPaymentId === "string" ?
        await firestoreTransaction.get(payments.doc(lockedPaymentId)) : null;
      const lockedData = lockedPayment?.data();
      if (lockedPayment?.exists && lockedData?.status === "pending" &&
          lockedData.expiresAt?.toDate?.() > now) {
        return {
          reused: true,
          paymentId: lockedPayment.id,
          data: lockedData,
        };
      }

      const existingReference = await firestoreTransaction.get(referenceRef);
      if (existingReference.exists) {
        throw new HttpsError("aborted", "Payment reference collision.");
      }

      firestoreTransaction.create(referenceRef, {
        userId: user.uid,
        paymentId: paymentRef.id,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });
      firestoreTransaction.create(paymentRef, {
        membershipId,
        provider: PROVIDER,
        amount,
        currency: String(membershipData.currency ?? "VND"),
        status: "pending",
        referenceNumber,
        description,
        expiresAt: Timestamp.fromDate(expiresAt),
        durationDays,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      firestoreTransaction.set(lockRef, {
        userId: user.uid,
        membershipId,
        paymentId: paymentRef.id,
        expiresAt: Timestamp.fromDate(expiresAt),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {reused: false, paymentId: paymentRef.id, data: null};
    });

    if (setup.reused && setup.data !== null) {
      let reusedData = setup.data;
      for (let attempt = 0; attempt < 8 && !reusedData.qrCode; attempt++) {
        await new Promise((resolve) => setTimeout(resolve, 250));
        reusedData = (await payments.doc(setup.paymentId).get()).data() ??
          reusedData;
      }
      if (!reusedData.qrCode) {
        throw new HttpsError(
          "aborted",
          "The existing payment order is still being prepared."
        );
      }
      return this.toOrderResult(setup.paymentId, reusedData);
    }
    try {
      const order = await this.paymentClient.createQrPay({
        amount,
        referenceNumber,
        description,
        expiresAt,
      });
      const paymentUpdate = {
        providerRequestId: order.providerRequestId,
        qrCode: order.qrCode,
        virtualAccountNumber: order.virtualAccountNumber ?? null,
        description: order.description ?? description,
        updatedAt: FieldValue.serverTimestamp(),
      };
      await paymentRef.update(paymentUpdate);
      return this.toOrderResult(paymentRef.id, {
        ...paymentUpdate,
        membershipId,
        amount,
        currency: String(membershipData.currency ?? "VND"),
        status: "pending",
        referenceNumber,
        expiresAt: Timestamp.fromDate(expiresAt),
      });
    } catch (error) {
      await Promise.all([
        paymentRef.update({
          status: "failed",
          failureReason: "provider_create_order_failed",
          updatedAt: FieldValue.serverTimestamp(),
        }),
        referenceRef.update({status: "failed"}),
      ]);
      throw error;
    }
  }

  async cancelOrder(userId: string, paymentId: string): Promise<void> {
    const paymentRef = db.collection(Collections.USERS).doc(userId)
      .collection(Collections.PAYMENTS).doc(paymentId);
    const payment = await paymentRef.get();
    if (!payment.exists) throwNotFound("Payment not found.");

    const currentData = payment.data() ?? {};
    if (currentData.status !== "pending") return;
    const providerRequestId = currentData.providerRequestId;
    if (typeof providerRequestId === "string" &&
        this.paymentClient.cancelPaymentOrder) {
      await this.paymentClient.cancelPaymentOrder(providerRequestId);
    }

    await db.runTransaction(async (firestoreTransaction) => {
      const latestPayment = await firestoreTransaction.get(paymentRef);
      if (!latestPayment.exists) throwNotFound("Payment not found.");
      const data = latestPayment.data() ?? {};
      if (data.status !== "pending") return;
      firestoreTransaction.update(paymentRef, {
        status: "cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      firestoreTransaction.update(
        db.collection(Collections.PAYMENT_REFERENCES)
          .doc(String(data.referenceNumber)),
        {status: "cancelled"}
      );
    });
  }

  async reconcile(
    transactionData: ProviderWebhookTransaction
  ): Promise<PaymentStatus> {
    if (!transactionData.referenceNumber) return "requires_review";
    const referenceRef = db.collection(Collections.PAYMENT_REFERENCES)
      .doc(transactionData.referenceNumber);

    return db.runTransaction(async (
      firestoreTransaction
    ): Promise<PaymentStatus> => {
      const reference = await firestoreTransaction.get(referenceRef);
      if (!reference.exists) return "requires_review";

      const referenceData = reference.data() ?? {};
      const paymentRef = db.collection(Collections.USERS)
        .doc(String(referenceData.userId)).collection(Collections.PAYMENTS)
        .doc(String(referenceData.paymentId));
      const providerTransactionRef = db
        .collection(Collections.PAYMENT_PROVIDER_TRANSACTIONS)
        .doc(transactionData.providerTransactionId);
      const [payment, duplicate] = await Promise.all([
        firestoreTransaction.get(paymentRef),
        firestoreTransaction.get(providerTransactionRef),
      ]);
      if (duplicate.exists) {
        return (payment.data()?.status as PaymentStatus | undefined) ??
          "completed";
      }
      if (!payment.exists) return "requires_review";

      const data = payment.data() ?? {};
      const paidAt = Timestamp.fromDate(transactionData.transactionDate);
      const expiresAt = data.expiresAt as Timestamp | undefined;
      const cancelledAt = data.cancelledAt as Timestamp | undefined;
      const isLate =
        (expiresAt !== undefined && paidAt.toMillis() > expiresAt.toMillis()) ||
        (cancelledAt !== undefined &&
          paidAt.toMillis() > cancelledAt.toMillis());
      const amountMatches = Number(data.amount) === transactionData.amount;
      const nextStatus: PaymentStatus = isLate || !amountMatches ?
        "requires_review" : "completed";

      const shouldActivate =
        nextStatus === "completed" && data.status !== "completed";
      const subscriptionRef = db.collection(Collections.USERS)
        .doc(String(referenceData.userId))
        .collection(Collections.SUBSCRIPTIONS)
        .doc(`${PROVIDER}_${String(data.membershipId)}`);
      const subscription = shouldActivate ?
        await firestoreTransaction.get(subscriptionRef) : null;

      firestoreTransaction.create(providerTransactionRef, {
        provider: PROVIDER,
        userId: referenceData.userId,
        paymentId: paymentRef.id,
        referenceNumber: transactionData.referenceNumber,
        amount: transactionData.amount,
        paidAt,
        createdAt: FieldValue.serverTimestamp(),
      });
      firestoreTransaction.update(paymentRef, {
        status: nextStatus,
        providerTransactionId: transactionData.providerTransactionId,
        paidAt,
        reviewReason: nextStatus === "requires_review" ?
          (isLate ? "late_payment" : "amount_mismatch") : null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      firestoreTransaction.update(referenceRef, {status: nextStatus});

      if (shouldActivate && subscription !== null) {
        const currentEnd = subscription.data()?.endDate as
          Timestamp | undefined;
        const startMillis = Math.max(
          paidAt.toMillis(),
          currentEnd?.toMillis() ?? 0
        );
        const endDate = Timestamp.fromMillis(
          startMillis + Number(data.durationDays) * 86400000
        );
        firestoreTransaction.set(subscriptionRef, {
          membershipId: data.membershipId,
          provider: PROVIDER,
          status: "active",
          startDate: subscription.exists ?
            subscription.data()?.startDate ?? paidAt : paidAt,
          endDate,
          autoRenew: false,
          cancelAtPeriodEnd: false,
          lastPaymentId: paymentRef.id,
          createdAt: subscription.exists ?
            subscription.data()?.createdAt ?? FieldValue.serverTimestamp() :
            FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        firestoreTransaction.update(
          db.collection(Collections.USERS)
            .doc(String(referenceData.userId)),
          {
            membershipId: data.membershipId,
            updatedAt: FieldValue.serverTimestamp(),
          }
        );
        firestoreTransaction.update(paymentRef, {
          subscriptionId: subscriptionRef.id,
        });
      }

      return nextStatus;
    });
  }

  private toOrderResult(
    paymentId: string,
    data: Record<string, unknown>
  ): PaymentOrderResult {
    const expiresAt = data.expiresAt as Timestamp;
    return {
      paymentId,
      membershipId: String(data.membershipId),
      amount: Number(data.amount),
      currency: String(data.currency ?? "VND"),
      status: String(data.status) as PaymentStatus,
      referenceNumber: String(data.referenceNumber),
      qrCode: String(data.qrCode),
      virtualAccountNumber: data.virtualAccountNumber ?
        String(data.virtualAccountNumber) : undefined,
      description: String(data.description),
      expiresAt: expiresAt.toDate().toISOString(),
    };
  }
}

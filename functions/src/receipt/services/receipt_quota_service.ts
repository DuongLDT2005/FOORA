import {FieldValue} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {throwResourceExhausted} from "../../utils/errors";

export class ReceiptQuotaService {
  /**
   * Checks if user has remaining receipt scan quota for the current calendar month.
   * If quota exceeded, throws ResourceExhausted error.
   * If within quota, atomically increments receiptScanUsed.
   */
  static async checkAndConsumeScanQuota(
    uid: string,
    membershipId: string
  ): Promise<{used: number; limit: number | null}> {
    // 1. Premium members have unlimited quota
    if (membershipId === "premium") {
      return {used: 0, limit: null};
    }

    // 2. Fetch membership configuration for Free tier
    const membershipDoc = await db
      .collection(Collections.MEMBERSHIPS)
      .doc(membershipId || "free")
      .get();

    let scanLimit: number | null = 5; // Default free quota from docs/DATABASE.md
    if (membershipDoc.exists) {
      scanLimit = membershipDoc.data()?.receiptScanQuota ?? 5;
    }

    // Unlimited limit
    if (scanLimit === null) {
      return {used: 0, limit: null};
    }

    // 3. Format current period (e.g. "2026-09")
    const now = new Date();
    const period = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

    const usageRef = db
      .collection(Collections.USERS)
      .doc(uid)
      .collection(Collections.AI_USAGE)
      .doc(Collections.AI_USAGE_CURRENT_DOC);

    let usedCount = 0;

    await db.runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      const currentData = usageDoc.data();

      // Reset count if period rolled over to new month
      if (!usageDoc.exists || currentData?.period !== period) {
        usedCount = 1;
        transaction.set(
          usageRef,
          {
            period,
            receiptScanUsed: 1,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
        return;
      }

      usedCount = (currentData.receiptScanUsed as number) || 0;
      if (usedCount >= scanLimit!) {
        throwResourceExhausted(
          `Bạn đã dùng hết lượt quét hóa đơn AI trong tháng (${usedCount}/${scanLimit} lượt). ` +
          "Vui lòng nâng cấp gói Premium để quét không giới hạn!"
        );
      }

      transaction.update(usageRef, {
        receiptScanUsed: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      usedCount += 1;
    });

    return {
      used: usedCount,
      limit: scanLimit,
    };
  }
}

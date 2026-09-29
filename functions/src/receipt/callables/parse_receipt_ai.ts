import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {FieldValue} from "firebase-admin/firestore";
import {REGION, db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {ReceiptQuotaService} from "../services/receipt_quota_service";
import {
  ReceiptParserService,
  EnrichedParsedItem,
} from "../services/receipt_parser";

interface ParseReceiptPayload {
  ocrText: string;
  householdId: string;
  imageBase64?: string;
  mimeType?: string;
}

interface ParseReceiptResult {
  receiptId: string;
  items: EnrichedParsedItem[];
  scansRemaining: number | null;
}

/**
 * Callable Function: parseReceiptAi
 * Accepts raw OCR text from client, verifies monthly scan quota,
 * extracts food items via Gemini AI, and enriches with smart inventory checks.
 */
export const parseReceiptAi = onCall<Partial<ParseReceiptPayload>>(
  {
    region: REGION,
    maxInstances: 10,
  },
  async (request): Promise<ApiResponse<ParseReceiptResult>> => {
    try {
      const user = await getAuthenticatedUser(request);
      const {ocrText, householdId, imageBase64, mimeType} = request.data || {};

      const normalizedOcrText =
        typeof ocrText === "string" ? ocrText.trim() : "";
      const normalizedImageBase64 =
        typeof imageBase64 === "string" && imageBase64.trim() ?
          imageBase64 :
          undefined;
      const normalizedMimeType =
        typeof mimeType === "string" && mimeType.trim() ? mimeType : undefined;

      if (!normalizedOcrText && !normalizedImageBase64) {
        throwInvalidArgument(
          "Phải cung cấp văn bản OCR hoặc ảnh hóa đơn."
        );
      }

      if (!householdId || typeof householdId !== "string") {
        throwInvalidArgument("Thiếu hoặc sai định dạng householdId.");
      }

      logger.info(
        `[parseReceiptAi] User ${user.uid} parsing receipt for household ${householdId} (hasImage: ${!!normalizedImageBase64})`
      );

      // 1. Quota verification (Free: 5/month, Premium: unlimited)
      const quotaResult = await ReceiptQuotaService.checkAndConsumeScanQuota(
        user.uid,
        user.membershipId
      );

      // 2. AI Parsing & Stock enrichment
      const enrichedItems = await ReceiptParserService.parseAndEnrich(
        normalizedOcrText,
        householdId,
        normalizedImageBase64,
        normalizedMimeType
      );

      // 3. Create receipt draft record in users/{userId}/receipts/{receiptId}
      const receiptRef = db
        .collection(Collections.USERS)
        .doc(user.uid)
        .collection(Collections.RECEIPTS)
        .doc();

      const serverTimestamp = FieldValue.serverTimestamp();
      await receiptRef.set({
        receiptId: receiptRef.id,
        householdId,
        imageUrl: null,
        status: "processing",
        ocrText: normalizedOcrText,
        processedBy: process.env.GEMINI_API_KEY ? "gemini-3.6-flash" : "rule-based",
        totalItemsDetected: enrichedItems.length,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });

      logger.info(
        `[parseReceiptAi] Created receipt record ${receiptRef.id} ` +
        `under users/${user.uid}/receipts/${receiptRef.id}`
      );

      const scansRemaining =
        quotaResult.limit !== null ? Math.max(0, quotaResult.limit - quotaResult.used) : null;

      return {
        success: true,
        data: {
          receiptId: receiptRef.id,
          items: enrichedItems,
          scansRemaining,
        },
        message: `Đã phân tích thành công ${enrichedItems.length} món từ hóa đơn!`,
      };
    } catch (error) {
      handleFunctionError(error, "parseReceiptAi");
    }
  }
);

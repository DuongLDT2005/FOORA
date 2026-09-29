import 'dart:typed_data';

import '../../domain/entities/receipt_item.dart';

abstract class ReceiptRepository {
  /// Scans receipt image with OCR and calls backend Gemini parser
  Future<({String? receiptId, List<ReceiptItem> items, int? scansRemaining})>
  scanAndParseReceipt({
    required Uint8List imageBytes,
    required String imagePath,
    required String mimeType,
    required String householdId,
  });

  /// Adds a batch of recognized items to the household inventory and completes receipt
  Future<int> batchAddReceiptItems({
    required String householdId,
    required List<ReceiptItem> items,
    String? receiptId,
  });
}

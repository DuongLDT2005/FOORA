import 'dart:typed_data';

import '../entities/receipt_item.dart';
import '../repositories/receipt_repository.dart';

class ScanReceiptUseCase {
  final ReceiptRepository repository;

  ScanReceiptUseCase(this.repository);

  Future<({String? receiptId, List<ReceiptItem> items, int? scansRemaining})>
  call({
    required Uint8List imageBytes,
    required String imagePath,
    required String mimeType,
    required String householdId,
  }) {
    return repository.scanAndParseReceipt(
      imageBytes: imageBytes,
      imagePath: imagePath,
      mimeType: mimeType,
      householdId: householdId,
    );
  }
}

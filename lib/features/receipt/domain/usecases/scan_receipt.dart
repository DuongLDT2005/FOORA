import 'dart:io';

import '../entities/receipt_item.dart';
import '../repositories/receipt_repository.dart';

class ScanReceiptUseCase {
  final ReceiptRepository repository;

  ScanReceiptUseCase(this.repository);

  Future<({String? receiptId, List<ReceiptItem> items, int? scansRemaining})>
  call({required File imageFile, required String householdId}) {
    return repository.scanAndParseReceipt(
      imageFile: imageFile,
      householdId: householdId,
    );
  }
}

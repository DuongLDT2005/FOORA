import '../entities/receipt_item.dart';
import '../repositories/receipt_repository.dart';

class ConfirmReceiptItemsUseCase {
  final ReceiptRepository repository;

  ConfirmReceiptItemsUseCase(this.repository);

  Future<int> call({
    required String householdId,
    required List<ReceiptItem> items,
    String? receiptId,
  }) {
    return repository.batchAddReceiptItems(
      householdId: householdId,
      items: items,
      receiptId: receiptId,
    );
  }
}

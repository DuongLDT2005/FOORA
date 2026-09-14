import 'dart:io';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../datasources/receipt_remote_datasource.dart';
import '../models/receipt_item_model.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  final ReceiptRemoteDataSource remoteDataSource;

  ReceiptRepositoryImpl({required this.remoteDataSource});

  @override
  Future<({String? receiptId, List<ReceiptItem> items, int? scansRemaining})> scanAndParseReceipt({
    required File imageFile,
    required String householdId,
  }) async {
    try {
      final ocrText = await remoteDataSource.extractOcrText(imageFile);
      if (ocrText.trim().isEmpty) {
        throw const ServerException(
          'Không tìm thấy chữ trên hóa đơn. Vui lòng chụp rõ nét hơn hoặc chọn góc đủ sáng.',
        );
      }

      return await remoteDataSource.parseReceiptAi(
        ocrText: ocrText,
        householdId: householdId,
        imageFile: imageFile,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure('Lỗi quét hóa đơn: $e');
    }
  }

  @override
  Future<int> batchAddReceiptItems({
    required String householdId,
    required List<ReceiptItem> items,
    String? receiptId,
  }) async {
    try {
      final models = items.map((i) {
        if (i is ReceiptItemModel) return i;
        return ReceiptItemModel(
          id: i.id,
          rawName: i.rawName,
          name: i.name,
          normalizedName: i.normalizedName,
          foodId: i.foodId,
          categoryId: i.categoryId,
          quantity: i.quantity,
          unit: i.unit,
          storageLocationId: i.storageLocationId,
          estimatedExpirationDate: i.estimatedExpirationDate,
          confidence: i.confidence,
          matchedExistingItem: i.matchedExistingItem,
        );
      }).toList();

      return await remoteDataSource.batchAddInventoryItems(
        householdId: householdId,
        items: models,
        receiptId: receiptId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure('Lỗi lưu các món từ hóa đơn: $e');
    }
  }
}

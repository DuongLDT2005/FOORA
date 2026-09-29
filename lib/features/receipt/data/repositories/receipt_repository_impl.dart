import 'dart:io';

import 'package:flutter/foundation.dart';

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
  Future<({String? receiptId, List<ReceiptItem> items, int? scansRemaining})>
  scanAndParseReceipt({
    required Uint8List imageBytes,
    required String imagePath,
    required String mimeType,
    required String householdId,
  }) async {
    try {
      var ocrText = '';
      if (!kIsWeb && imagePath.isNotEmpty) {
        try {
          ocrText = await remoteDataSource.extractOcrText(File(imagePath));
        } on ServerException {
          // Gemini can still read the original image if on-device OCR fails.
          ocrText = '';
        }
      }

      return await remoteDataSource.parseReceiptAi(
        ocrText: ocrText,
        householdId: householdId,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (_) {
      throw const ServerFailure(
        'Đã xảy ra lỗi khi quét hóa đơn. Vui lòng thử lại.',
      );
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
    } catch (_) {
      throw const ServerFailure(
        'Đã xảy ra lỗi khi lưu các món từ hóa đơn. Vui lòng thử lại sau.',
      );
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/receipt_item_model.dart';

abstract class ReceiptRemoteDataSource {
  /// Extracts raw text from an image file using Google ML Kit on-device
  Future<String> extractOcrText(File imageFile);

  /// Calls Cloud Function parseReceiptAi to parse items and check smart inventory
  Future<({String? receiptId, List<ReceiptItemModel> items, int? scansRemaining})> parseReceiptAi({
    required String ocrText,
    required String householdId,
    File? imageFile,
  });

  /// Calls Cloud Function batchAddInventoryItems to save all items into household inventory
  Future<int> batchAddInventoryItems({
    required String householdId,
    required List<ReceiptItemModel> items,
    String? receiptId,
  });
}

class ReceiptRemoteDataSourceImpl implements ReceiptRemoteDataSource {
  final FirebaseFunctions functions;
  final TextRecognizer _textRecognizer;

  ReceiptRemoteDataSourceImpl({
    required this.functions,
    TextRecognizer? textRecognizer,
  }) : _textRecognizer =
           textRecognizer ??
           TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractOcrText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      throw ServerException('Lỗi nhận diện văn bản từ hóa đơn: $e');
    }
  }

  @override
  Future<({String? receiptId, List<ReceiptItemModel> items, int? scansRemaining})> parseReceiptAi({
    required String ocrText,
    required String householdId,
    File? imageFile,
  }) async {
    try {
      final callable = functions.httpsCallable(
        'parseReceiptAi',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      String? imageBase64;
      String? mimeType;
      if (imageFile != null && await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        imageBase64 = base64Encode(bytes);
        final pathLower = imageFile.path.toLowerCase();
        if (pathLower.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (pathLower.endsWith('.webp')) {
          mimeType = 'image/webp';
        } else {
          mimeType = 'image/jpeg';
        }
      }

      final response = await callable.call<Map<String, dynamic>>({
        'ocrText': ocrText,
        'householdId': householdId,
        'imageBase64': ?imageBase64,
        'mimeType': ?mimeType,
      });

      final resData = response.data;
      if (resData['success'] != true) {
        throw ServerException(
          resData['message']?.toString() ?? 'Không thể phân tích hóa đơn.',
        );
      }

      final data = resData['data'] as Map<String, dynamic>? ?? {};
      final receiptId = data['receiptId'] as String?;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final scansRemaining = (data['scansRemaining'] as num?)?.toInt();

      final items =
          rawItems
              .map(
                (item) =>
                    ReceiptItemModel.fromBackendJson(item as Map<String, dynamic>),
              )
              .toList();

      return (receiptId: receiptId, items: items, scansRemaining: scansRemaining);
    } on FirebaseFunctionsException catch (fe) {
      throw ServerException(fe.message ?? 'Lỗi máy chủ khi phân tích hóa đơn.');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Lỗi kết nối khi phân tích hóa đơn: $e');
    }
  }

  @override
  Future<int> batchAddInventoryItems({
    required String householdId,
    required List<ReceiptItemModel> items,
    String? receiptId,
  }) async {
    try {
      final callable = functions.httpsCallable(
        'batchAddInventoryItems',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final payload = items.map((i) => i.toInventoryItemJson()).toList();

      final response = await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'items': payload,
        'receiptId': ?receiptId,
      });

      final resData = response.data;
      if (resData['success'] != true) {
        throw ServerException(
          resData['message']?.toString() ?? 'Không thể lưu thực phẩm vào kho.',
        );
      }

      final data = resData['data'] as Map<String, dynamic>? ?? {};
      return (data['addedCount'] as num?)?.toInt() ?? items.length;
    } on FirebaseFunctionsException catch (fe) {
      throw ServerException(fe.message ?? 'Lỗi khi lưu các món vào tủ lạnh.');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Lỗi kết nối khi lưu thực phẩm: $e');
    }
  }
}

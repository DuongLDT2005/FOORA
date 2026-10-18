import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/receipt_item_model.dart';

/// Contract for the receipt scanning pipeline: on-device OCR -> AI parsing -> save.
abstract class ReceiptRemoteDataSource {
  /// Extracts raw text from an image file using Google ML Kit on-device
  Future<String> extractOcrText(File imageFile);

  /// Calls Cloud Function parseReceiptAi to parse items and check smart inventory
  Future<
    ({String? receiptId, List<ReceiptItemModel> items, int? scansRemaining})
  >
  parseReceiptAi({
    required String ocrText,
    required String householdId,
    required Uint8List imageBytes,
    required String mimeType,
  });

  /// Calls Cloud Function batchAddInventoryItems to save all items into household inventory
  Future<int> batchAddInventoryItems({
    required String householdId,
    required List<ReceiptItemModel> items,
    String? receiptId,
  });

  /// Streams `users/{uid}/ai_usage/current.receiptScanUsed` for [period];
  /// a stale period counts as 0 because the backend resets it on next use.
  Stream<int> watchMonthlyScanUsage({required String period});
}

/// ML Kit + Cloud Functions implementation of [ReceiptRemoteDataSource].
class ReceiptRemoteDataSourceImpl implements ReceiptRemoteDataSource {
  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final TextRecognizer _textRecognizer;

  ReceiptRemoteDataSourceImpl({
    required this.functions,
    required this.firestore,
    required this.auth,
    TextRecognizer? textRecognizer,
  }) : _textRecognizer =
           textRecognizer ??
           TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs ML Kit Latin text recognition on the image and returns the raw text.
  @override
  Future<String> extractOcrText(File imageFile) async {
    if (kIsWeb) {
      throw const ServerException(
        'Tính năng quét OCR on-device chỉ hỗ trợ trên ứng dụng mobile.',
      );
    }
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Lỗi nhận diện văn bản từ hóa đơn: $e');
    }
  }

  @override
  Future<
    ({String? receiptId, List<ReceiptItemModel> items, int? scansRemaining})
  >
  parseReceiptAi({
    required String ocrText,
    required String householdId,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    try {
      final callable = functions.httpsCallable(
        'parseReceiptAi',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final imageBase64 = base64Encode(imageBytes);

      final response = await callable.call<Map<String, dynamic>>({
        'ocrText': ocrText,
        'householdId': householdId,
        'imageBase64': imageBase64,
        'mimeType': mimeType,
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

      final items = rawItems
          .map(
            (item) =>
                ReceiptItemModel.fromBackendJson(item as Map<String, dynamic>),
          )
          .toList();

      return (
        receiptId: receiptId,
        items: items,
        scansRemaining: scansRemaining,
      );
    } on FirebaseFunctionsException catch (fe) {
      throw ServerException(fe.message ?? 'Lỗi máy chủ khi phân tích hóa đơn.');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Lỗi kết nối khi phân tích hóa đơn: $e');
    }
  }

  /// Sends the confirmed items to `batchAddInventoryItems`; returns how many were added.
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

  @override
  Stream<int> watchMonthlyScanUsage({required String period}) {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      return Stream.error(
        const AuthException('Vui lòng đăng nhập để xem hạn mức quét.'),
      );
    }
    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.aiUsage)
        .doc(FirestoreConstants.aiUsageCurrentDoc)
        .snapshots()
        .map((document) {
          final data = document.data();
          if (data == null || data['period'] != period) return 0;
          return (data['receiptScanUsed'] as num?)?.toInt() ?? 0;
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw ServerException.fromFirebase(error);
          }
          throw ServerException(error.toString());
        });
  }
}

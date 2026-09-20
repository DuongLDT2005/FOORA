import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/receipt_remote_datasource.dart';
import '../../data/repositories/receipt_repository_impl.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../../domain/usecases/confirm_receipt_items.dart';
import '../../domain/usecases/scan_receipt.dart';

// --- Data & Domain Providers ---

/// Model representing the user's monthly receipt scan quota status
class ReceiptQuotaStatus {
  final int scansUsed;
  final int scanLimit;
  final bool isUnlimited;

  const ReceiptQuotaStatus({
    this.scansUsed = 0,
    this.scanLimit = 5,
    this.isUnlimited = false,
  });

  bool get isQuotaExceeded => !isUnlimited && scansUsed >= scanLimit;
  int get scansRemaining => isUnlimited ? 999999 : (scanLimit - scansUsed).clamp(0, scanLimit);
}

/// Streams real-time monthly scan usage directly from Firestore database
final receiptQuotaProvider = StreamProvider.autoDispose<ReceiptQuotaStatus>((ref) {
  final authUser = ref.watch(firebaseAuthProvider).currentUser;
  if (authUser == null) {
    return Stream.value(const ReceiptQuotaStatus());
  }

  final firestore = ref.watch(firestoreProvider);
  final uid = authUser.uid;

  final now = DateTime.now();
  final currentPeriod = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  // Listen directly to user document snapshot to get real-time membershipId from database
  return firestore
      .collection(FirestoreConstants.users)
      .doc(uid)
      .snapshots()
      .asyncExpand((userDoc) async* {
        if (!userDoc.exists) {
          yield const ReceiptQuotaStatus(scansUsed: 0, scanLimit: 5);
          return;
        }

        final userData = userDoc.data();
        final membershipId = (userData?['membershipId'] as String?) ?? 'free';

        // 1. Premium members have unlimited scans
        if (membershipId == 'premium') {
          yield const ReceiptQuotaStatus(isUnlimited: true);
          return;
        }

        // 2. Fetch membership scan quota limit from memberships collection
        int scanLimit = 5;
        try {
          final membershipDoc = await firestore
              .collection(FirestoreConstants.memberships)
              .doc(membershipId)
              .get();
          if (membershipDoc.exists) {
            final quota = membershipDoc.data()?['receiptScanQuota'];
            if (quota == null) {
              // null in DB means unlimited
              yield const ReceiptQuotaStatus(isUnlimited: true);
              return;
            }
            scanLimit = (quota as num).toInt();
          }
        } catch (_) {
          scanLimit = 5;
        }

        // 3. Listen directly to users/{uid}/ai_usage/current in Firestore
        yield* firestore
            .collection(FirestoreConstants.users)
            .doc(uid)
            .collection(FirestoreConstants.aiUsage)
            .doc(FirestoreConstants.aiUsageCurrentDoc)
            .snapshots()
            .map((usageDoc) {
              if (!usageDoc.exists) {
                return ReceiptQuotaStatus(scansUsed: 0, scanLimit: scanLimit);
              }

              final usageData = usageDoc.data();
              if (usageData == null) {
                return ReceiptQuotaStatus(scansUsed: 0, scanLimit: scanLimit);
              }

              final period = usageData['period'] as String?;
              if (period != currentPeriod) {
                return ReceiptQuotaStatus(scansUsed: 0, scanLimit: scanLimit);
              }

              final used = (usageData['receiptScanUsed'] as num?)?.toInt() ?? 0;
              return ReceiptQuotaStatus(
                scansUsed: used,
                scanLimit: scanLimit,
                isUnlimited: false,
              );
            });
      });
});


final receiptRemoteDataSourceProvider = Provider<ReceiptRemoteDataSource>((
  ref,
) {
  return ReceiptRemoteDataSourceImpl(functions: ref.watch(functionsProvider));
});

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepositoryImpl(
    remoteDataSource: ref.watch(receiptRemoteDataSourceProvider),
  );
});

final scanReceiptUseCaseProvider = Provider<ScanReceiptUseCase>((ref) {
  return ScanReceiptUseCase(ref.watch(receiptRepositoryProvider));
});

final confirmReceiptItemsUseCaseProvider = Provider<ConfirmReceiptItemsUseCase>(
  (ref) {
    return ConfirmReceiptItemsUseCase(ref.watch(receiptRepositoryProvider));
  },
);

// --- Receipt Scan State & Notifier ---

enum ScanStatus {
  idle,
  capturing,
  processing, // OCR + Gemini AI
  reviewing, // Shows BottomSheet with parsed items
  submitting, // Batch saving to inventory
  success,
  error,
}

class ReceiptScanState {
  final String? receiptId;
  final ScanStatus status;
  final File? capturedImage;
  final List<ReceiptItem> parsedItems;
  final int? scansRemaining;
  final String? errorMessage;
  final String? successMessage;
  final bool isFlashOn;

  const ReceiptScanState({
    this.receiptId,
    this.status = ScanStatus.idle,
    this.capturedImage,
    this.parsedItems = const [],
    this.scansRemaining,
    this.errorMessage,
    this.successMessage,
    this.isFlashOn = false,
  });

  ReceiptScanState copyWith({
    String? receiptId,
    ScanStatus? status,
    File? capturedImage,
    List<ReceiptItem>? parsedItems,
    int? scansRemaining,
    String? errorMessage,
    String? successMessage,
    bool? isFlashOn,
  }) {
    return ReceiptScanState(
      receiptId: receiptId ?? this.receiptId,
      status: status ?? this.status,
      capturedImage: capturedImage ?? this.capturedImage,
      parsedItems: parsedItems ?? this.parsedItems,
      scansRemaining: scansRemaining ?? this.scansRemaining,
      errorMessage: errorMessage,
      successMessage: successMessage,
      isFlashOn: isFlashOn ?? this.isFlashOn,
    );
  }
}

final receiptScanNotifierProvider =
    StateNotifierProvider.autoDispose<ReceiptScanNotifier, ReceiptScanState>((
      ref,
    ) {
      final scanUseCase = ref.watch(scanReceiptUseCaseProvider);
      final confirmUseCase = ref.watch(confirmReceiptItemsUseCaseProvider);
      return ReceiptScanNotifier(
        ref: ref,
        scanUseCase: scanUseCase,
        confirmUseCase: confirmUseCase,
      );
    });

class ReceiptScanNotifier extends StateNotifier<ReceiptScanState> {
  final Ref ref;
  final ScanReceiptUseCase scanUseCase;
  final ConfirmReceiptItemsUseCase confirmUseCase;
  final ImagePicker _picker = ImagePicker();

  ReceiptScanNotifier({
    required this.ref,
    required this.scanUseCase,
    required this.confirmUseCase,
  }) : super(const ReceiptScanState());

  void toggleFlash() {
    state = state.copyWith(isFlashOn: !state.isFlashOn);
  }

  void reset() {
    state = const ReceiptScanState();
  }

  /// Takes a photo using device camera
  Future<void> captureImageFromCamera() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (photo != null) {
        await processImage(File(photo.path));
      }
    } catch (_) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Không thể mở máy ảnh. Vui lòng cấp quyền máy ảnh và thử lại.',
      );
    }
  }

  /// Picks an existing receipt image from gallery
  Future<void> pickImageFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        await processImage(File(image.path));
      }
    } catch (_) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Không thể chọn ảnh từ thư viện. Vui lòng thử lại.',
      );
    }
  }

  /// Processes the image through OCR and backend Gemini parser
  Future<void> processImage(File imageFile) async {
    final user = ref.read(currentUserProvider);
    final householdId = user?.activeHouseholdId;

    if (householdId == null || householdId.isEmpty) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage:
            'Chưa có thông tin tủ lạnh gia đình. Vui lòng đăng nhập lại.',
      );
      return;
    }

    state = state.copyWith(
      status: ScanStatus.processing,
      capturedImage: imageFile,
      errorMessage: null,
    );

    try {
      final result = await scanUseCase(
        imageFile: imageFile,
        householdId: householdId,
      );

      if (result.items.isEmpty) {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage:
              'Không tìm thấy thực phẩm nào trong hóa đơn. Vui lòng thử lại với ảnh rõ hơn.',
        );
        return;
      }

      state = state.copyWith(
        status: ScanStatus.reviewing,
        receiptId: result.receiptId,
        parsedItems: result.items,
        scansRemaining: result.scansRemaining,
      );
    } on Failure catch (f) {
      state = state.copyWith(status: ScanStatus.error, errorMessage: f.message);
    } catch (_) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Đã xảy ra lỗi khi quét hóa đơn. Vui lòng thử lại.',
      );
    }
  }

  /// Removes an unwanted item from the scanned items list
  void removeItem(int index) {
    if (index >= 0 && index < state.parsedItems.length) {
      final updatedList = List<ReceiptItem>.from(state.parsedItems)
        ..removeAt(index);
      if (updatedList.isEmpty) {
        state = state.copyWith(
          status: ScanStatus.idle,
          parsedItems: [],
          capturedImage: null,
        );
      } else {
        state = state.copyWith(parsedItems: updatedList);
      }
    }
  }

  /// Updates an item in the scanned list (e.g. after user edits in ItemFormPage)
  void updateItem(int index, ReceiptItem updatedItem) {
    if (index >= 0 && index < state.parsedItems.length) {
      final updatedList = List<ReceiptItem>.from(state.parsedItems);
      updatedList[index] = updatedItem;
      state = state.copyWith(parsedItems: updatedList);
    }
  }

  /// Batch saves all items in state.parsedItems into the household inventory
  Future<bool> submitAllItems() async {
    final user = ref.read(currentUserProvider);
    final householdId = user?.activeHouseholdId;

    if (householdId == null || householdId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Chưa có thông tin tủ lạnh gia đình.',
      );
      return false;
    }

    if (state.parsedItems.isEmpty) {
      return false;
    }

    state = state.copyWith(status: ScanStatus.submitting, errorMessage: null);

    try {
      final addedCount = await confirmUseCase(
        householdId: householdId,
        items: state.parsedItems,
        receiptId: state.receiptId,
      );

      state = state.copyWith(
        status: ScanStatus.success,
        successMessage: 'Đã thêm thành công $addedCount món vào tủ lạnh!',
      );
      return true;
    } on Failure catch (f) {
      state = state.copyWith(
        status: ScanStatus.reviewing,
        errorMessage: f.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: ScanStatus.reviewing,
        errorMessage: 'Không thể lưu thực phẩm. Vui lòng thử lại sau.',
      );
      return false;
    }
  }
}

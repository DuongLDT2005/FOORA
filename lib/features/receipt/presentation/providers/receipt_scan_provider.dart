import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../data/datasources/receipt_remote_datasource.dart';
import '../../data/repositories/receipt_repository_impl.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/entities/receipt_scan_quota.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../../domain/usecases/confirm_receipt_items.dart';
import '../../domain/usecases/scan_receipt.dart';
import '../../domain/usecases/watch_receipt_scan_quota.dart';

// --- Data & Domain Providers ---

final receiptRemoteDataSourceProvider = Provider<ReceiptRemoteDataSource>((
  ref,
) {
  return ReceiptRemoteDataSourceImpl(
    functions: ref.watch(functionsProvider),
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
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

final watchReceiptScanQuotaUseCaseProvider =
    Provider<WatchReceiptScanQuotaUseCase>((ref) {
      return WatchReceiptScanQuotaUseCase(
        membershipRepository: ref.watch(membershipRepositoryProvider),
        receiptRepository: ref.watch(receiptRepositoryProvider),
      );
    });

/// Real-time monthly receipt-scan quota of the signed-in user.
final receiptQuotaProvider = StreamProvider.autoDispose<ReceiptScanQuota>((
  ref,
) {
  // Re-subscribe whenever the signed-in user changes.
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(watchReceiptScanQuotaUseCaseProvider).call();
});

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
  final Uint8List? capturedImageBytes;
  final List<ReceiptItem> parsedItems;
  final int? scansRemaining;
  final String? errorMessage;
  final String? successMessage;
  final bool isFlashOn;

  const ReceiptScanState({
    this.receiptId,
    this.status = ScanStatus.idle,
    this.capturedImageBytes,
    this.parsedItems = const [],
    this.scansRemaining,
    this.errorMessage,
    this.successMessage,
    this.isFlashOn = false,
  });

  ReceiptScanState copyWith({
    String? receiptId,
    ScanStatus? status,
    Uint8List? capturedImageBytes,
    bool clearCapturedImage = false,
    List<ReceiptItem>? parsedItems,
    int? scansRemaining,
    String? errorMessage,
    String? successMessage,
    bool? isFlashOn,
  }) {
    return ReceiptScanState(
      receiptId: receiptId ?? this.receiptId,
      status: status ?? this.status,
      capturedImageBytes: clearCapturedImage
          ? null
          : capturedImageBytes ?? this.capturedImageBytes,
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
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (photo != null) {
        await _processPickedImage(photo);
      }
    } catch (_) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage:
            'Không thể mở máy ảnh. Vui lòng cấp quyền máy ảnh và thử lại.',
      );
    }
  }

  /// Picks an existing receipt image from gallery
  Future<void> pickImageFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null) {
        await _processPickedImage(image);
      }
    } catch (_) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Không thể chọn ảnh từ thư viện. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _processPickedImage(XFile image) async {
    final imageBytes = await image.readAsBytes();
    if (imageBytes.isEmpty) {
      throw StateError('Selected receipt image is empty.');
    }

    await processImage(
      imageBytes: imageBytes,
      imagePath: image.path,
      mimeType: image.mimeType ?? _mimeTypeFromName(image.name),
    );
  }

  String _mimeTypeFromName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  /// Processes the image through OCR and backend Gemini parser.
  Future<void> processImage({
    required Uint8List imageBytes,
    required String imagePath,
    required String mimeType,
  }) async {
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
      capturedImageBytes: imageBytes,
      errorMessage: null,
    );

    try {
      final result = await scanUseCase(
        imageBytes: imageBytes,
        imagePath: imagePath,
        mimeType: mimeType,
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
          clearCapturedImage: true,
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

  /// Builds an unsaved [InventoryItem] from a scanned item so it can be
  /// reviewed in the item form.
  InventoryItem buildEditDraft(int index, {DateTime? now}) {
    final item = state.parsedItems[index];
    final timestamp = now ?? DateTime.now();
    return InventoryItem(
      id: '',
      foodId: item.foodId,
      name: item.name,
      normalizedName: item.normalizedName,
      categoryId: item.categoryId,
      quantity: item.quantity,
      unit: item.unit,
      remainingPercentage: 100,
      storageLocationId: item.storageLocationId,
      purchaseDate: timestamp,
      expirationDate: item.estimatedExpirationDate,
      source: InventoryItemSource.receiptScan,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Copies the fields edited in the item form back onto the scanned item.
  void applyEditedDraft(int index, InventoryItem edited) {
    if (index < 0 || index >= state.parsedItems.length) return;
    updateItem(
      index,
      state.parsedItems[index].copyWith(
        name: edited.name,
        categoryId: edited.categoryId,
        quantity: edited.quantity,
        unit: edited.unit,
        storageLocationId: edited.storageLocationId,
        estimatedExpirationDate: edited.expirationDate,
      ),
    );
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

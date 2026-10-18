import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../providers/receipt_scan_provider.dart';
import '../widgets/scan_status_overlays.dart';
import '../widgets/scan_viewfinder_widget.dart';
import '../widgets/scanned_items_bottom_sheet.dart';

/// Receipt Scan Tab Page matching Stitch Screen:
/// `Quét hóa đơn (Đã cập nhật List)` with Live Camera Feed
class ReceiptScanPage extends ConsumerStatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  ConsumerState<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends ConsumerState<ReceiptScanPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  CameraController? _cameraController;
  bool get _isCameraInitialized =>
      _cameraController?.value.isInitialized ?? false;
  bool _isCameraInitializing = false;
  String? _cameraErrorMessage;

  /// Whether this tab is the visible branch of the shell (inactive branches
  /// are wrapped in a disabled [TickerMode] by go_router).
  bool _isTabActive = true;

  /// Whether the app / browser tab is in the foreground.
  bool _isAppForeground = true;

  bool get _shouldRunCamera => mounted && _isTabActive && _isAppForeground;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTabActive = TickerMode.valuesOf(context).enabled;
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // On web, `inactive` fires whenever the window loses focus (file dialog,
    // address bar...), so only release the camera once the page is hidden.
    final releaseOnInactive = !kIsWeb;
    _isAppForeground =
        lifecycleState == AppLifecycleState.resumed ||
        (lifecycleState == AppLifecycleState.inactive && !releaseOnInactive);
    _syncCamera();
  }

  void _syncCamera() {
    if (_shouldRunCamera) {
      if (_cameraController == null) _initializeCamera();
    } else {
      _releaseCamera();
    }
  }

  void _releaseCamera() {
    final controller = _cameraController;
    if (controller == null) return;
    _cameraController = null;
    if (mounted) setState(() {});
    controller.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraErrorMessage = 'Không tìm thấy máy ảnh trên thiết bị này.';
            _isCameraInitializing = false;
          });
        }
        return;
      }

      // Prioritize back camera for receipt scanning
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );

      await controller.initialize();

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      // User may have left the tab / backgrounded the app while initializing.
      if (!_shouldRunCamera) {
        _isCameraInitializing = false;
        await controller.dispose();
        return;
      }

      _cameraController = controller;

      setState(() {
        _cameraErrorMessage = null;
        _isCameraInitializing = false;
      });
    } catch (e) {
      _isCameraInitializing = false;
      if (mounted) {
        setState(() {
          _cameraErrorMessage =
              'Không thể khởi động camera. Vui lòng cấp quyền truy cập máy ảnh.';
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    final scanNotifier = ref.read(receiptScanNotifierProvider.notifier);
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      XFile? xFile;
      Uint8List? bytes;
      try {
        xFile = await controller.takePicture();
        bytes = await xFile.readAsBytes();
      } catch (_) {
        // Fall through to ImagePicker if the live camera fails to capture
      }
      if (xFile != null && bytes != null) {
        await scanNotifier.processImage(
          imageBytes: bytes,
          imagePath: xFile.path,
          mimeType: xFile.mimeType ?? 'image/jpeg',
        );
        return;
      }
    }
    // Fallback if camera controller is not available
    await scanNotifier.captureImageFromCamera();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    final scanNotifier = ref.read(receiptScanNotifierProvider.notifier);
    scanNotifier.toggleFlash();
    final isFlashOn = ref.read(receiptScanNotifierProvider).isFlashOn;

    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFlashMode(
          isFlashOn ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scanState = ref.watch(receiptScanNotifierProvider);
    final scanNotifier = ref.read(receiptScanNotifierProvider.notifier);
    final quotaAsync = ref.watch(receiptQuotaProvider);
    final quotaStatus = quotaAsync.valueOrNull;
    final isBlocked = quotaStatus?.isQuotaExceeded ?? false;

    ref.listen<ReceiptScanState>(receiptScanNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage &&
          (next.status == ScanStatus.error ||
              next.status == ScanStatus.reviewing)) {
        ToastHelper.show(context, next.errorMessage!, isError: true);
      }
      if (next.status == ScanStatus.success && next.successMessage != null) {
        ToastHelper.show(context, next.successMessage!);
        scanNotifier.reset();
        context.go(AppRouteNames.inventory);
      }
    });

    final isProcessing = scanState.status == ScanStatus.processing;
    final isReviewing =
        scanState.status == ScanStatus.reviewing ||
        scanState.status == ScanStatus.submitting;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera / Captured Image Layer
          Positioned.fill(
            child: scanState.capturedImageBytes != null
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.0,
                      child: Image.memory(
                        scanState.capturedImageBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  )
                : (_isCameraInitialized && _cameraController != null)
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize != null
                                ? (_cameraController!.value.previewSize!.width >
                                          _cameraController!
                                              .value
                                              .previewSize!
                                              .height
                                      ? _cameraController!
                                            .value
                                            .previewSize!
                                            .height
                                      : _cameraController!
                                            .value
                                            .previewSize!
                                            .width)
                                : MediaQuery.of(context).size.width,
                            height: _cameraController!.value.previewSize != null
                                ? (_cameraController!.value.previewSize!.width >
                                          _cameraController!
                                              .value
                                              .previewSize!
                                              .height
                                      ? _cameraController!
                                            .value
                                            .previewSize!
                                            .width
                                      : _cameraController!
                                            .value
                                            .previewSize!
                                            .height)
                                : MediaQuery.of(context).size.height,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.slate900,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.camera,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.w),
                            child: Text(
                              _cameraErrorMessage ??
                                  'Nhấn vào nút bên dưới để cấp quyền máy ảnh cho FOORA.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(LucideIcons.camera, size: 18),
                            label: const Text('Bật máy ảnh'),
                            onPressed: () {
                              _initializeCamera();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Viewfinder Cutout (hidden when reviewing sheet is up)
          if (!isReviewing)
            Positioned.fill(
              child: ScanViewfinderWidget(
                bottomChild: (!isProcessing && !isBlocked)
                    ? GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 70,
                          height: 70,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.camera,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),

          // 3. Top Controls (Gallery, Flash, Close)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Pick from Gallery button
                    _buildCircleIconButton(
                      icon: LucideIcons.image,
                      onTap: (isProcessing || isBlocked)
                          ? null
                          : () => scanNotifier.pickImageFromGallery(),
                    ),
                    const SizedBox(width: 12),
                    // Flash Toggle button
                    _buildCircleIconButton(
                      icon: scanState.isFlashOn
                          ? LucideIcons.zap
                          : LucideIcons.zapOff,
                      color: scanState.isFlashOn
                          ? AppColors.amber500
                          : Colors.white,
                      onTap: isBlocked ? null : _toggleFlash,
                    ),
                  ],
                ),

                // Close / Reset button
                _buildCircleIconButton(
                  icon: LucideIcons.x,
                  onTap: () {
                    if (isReviewing || scanState.capturedImageBytes != null) {
                      scanNotifier.reset();
                    } else {
                      context.go(AppRouteNames.home);
                    }
                  },
                ),
              ],
            ),
          ),

          // 3.5 Persistent quota-exceeded card (visible while the limit is reached)
          if (isBlocked && !isReviewing)
            Positioned.fill(
              child: QuotaExceededOverlay(
                scansUsed: quotaStatus?.scansUsed ?? 0,
                scanLimit: quotaStatus?.scanLimit ?? 0,
              ),
            ),

          // 4. Processing Overlay (AI analyzing)
          if (isProcessing)
            const Positioned.fill(child: ScanProcessingOverlay()),

          // 6. Scanned Items Bottom Sheet (Stitch UI Screen)
          if (isReviewing && scanState.parsedItems.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ScannedItemsBottomSheet(
                items: scanState.parsedItems,
                isSubmitting: scanState.status == ScanStatus.submitting,
                onItemDelete: (index) => scanNotifier.removeItem(index),
                onAddAll: () => scanNotifier.submitAllItems(),
                onItemTap: (index) async {
                  // Open ItemFormPage prefilled with recognized data
                  final updated = await context.push<InventoryItem>(
                    AppRouteNames.itemForm,
                    extra: scanNotifier.buildEditDraft(index),
                  );
                  if (updated != null && mounted) {
                    scanNotifier.applyEditedDraft(index, updated);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 18.r),
        ),
      ),
    );
  }
}

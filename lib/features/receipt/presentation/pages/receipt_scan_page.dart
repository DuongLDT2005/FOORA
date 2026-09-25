import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../providers/receipt_scan_provider.dart';
import '../widgets/scan_viewfinder_widget.dart';
import '../widgets/scanned_items_bottom_sheet.dart';

/// Receipt Scan Tab Page matching Stitch Screen:
/// `Quét hóa đơn (Đã cập nhật List)`
class ReceiptScanPage extends ConsumerStatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  ConsumerState<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends ConsumerState<ReceiptScanPage> {
  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(receiptScanNotifierProvider);
    final scanNotifier = ref.read(receiptScanNotifierProvider.notifier);
    final quotaAsync = ref.watch(receiptQuotaProvider);
    final quotaStatus = quotaAsync.valueOrNull ?? const ReceiptQuotaStatus();
    final isBlocked = quotaStatus.isQuotaExceeded;

    ref.listen<ReceiptScanState>(receiptScanNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage &&
          (next.status == ScanStatus.error ||
              next.status == ScanStatus.reviewing)) {
        ToastHelper.show(context, next.errorMessage!, isError: true);
      }
      if (next.status == ScanStatus.success && next.successMessage != null) {
        ToastHelper.show(context, next.successMessage!);
        // Reset scan state completely back to initial camera viewfinder
        scanNotifier.reset();
        // Navigate back to Inventory tab to see newly added items
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
          // 1. Camera / Mock Viewfinder Layer
          Positioned.fill(
            child: scanState.capturedImage != null
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Image.file(
                      scanState.capturedImage!,
                      fit: BoxFit.contain, // Hiển thị trọn vẹn ảnh, tự co theo chiều lớn hơn (ngang hoặc dọc) không bị cắt
                    ),
                  )
                : Container(
                    color: const Color(0xFF0F172A), // Slate 900
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.scanLine,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Khung hình máy ảnh',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
                        onTap: scanNotifier.captureImageFromCamera,
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
                      onTap: isBlocked ? null : scanNotifier.toggleFlash,
                    ),
                  ],
                ),

                // Close / Reset button
                _buildCircleIconButton(
                  icon: LucideIcons.x,
                  onTap: () {
                    if (isReviewing || scanState.capturedImage != null) {
                      scanNotifier.reset();
                    } else {
                      context.go(AppRouteNames.home);
                    }
                  },
                ),
              ],
            ),
          ),

          // 3.5 Persistent Quota Exceeded Card Overlay (Always visible in scan tab if free limit reached)
          if (isBlocked && !isReviewing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 440.w),
                    child: Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24.r,
                            offset: Offset(0, 8.h),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60.r,
                            height: 60.r,
                            decoration: const BoxDecoration(
                              color: AppColors.amber100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.crown,
                              size: 32.r,
                              color: AppColors.amber500,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          Text(
                            'Hết lượt quét hóa đơn',
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            'Bạn đã sử dụng hết ${quotaStatus.scansUsed}/${quotaStatus.scanLimit} lượt quét hóa đơn AI miễn phí trong tháng này. Hãy nâng cấp gói Premium để tận hưởng lượt quét không giới hạn!',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.slate600,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24.h),
                          Row(
                            children: [
                              Expanded(
                                child: SecondaryButton(
                                  text: 'Để sau',
                                  onPressed: () {
                                    context.go(AppRouteNames.home);
                                  },
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: PrimaryButton(
                                  text: 'Nâng cấp',
                                  onPressed: () {
                                    context.push(AppRouteNames.membership);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Processing Overlay (AI analyzing)
          if (isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 440.w),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 20.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36.r,
                            height: 36.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Đang phân tích hóa đơn bằng AI...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                              color: AppColors.slate800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Tự động bóc tách tên món, số lượng và đơn vị',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12.sp,
                              color: AppColors.slate500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

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
                  final item = scanState.parsedItems[index];
                  // Open ItemFormPage prefilled with recognized data
                  final now = DateTime.now();
                  final dummyItem = InventoryItem(
                    id: '',
                    foodId: item.foodId,
                    name: item.name,
                    normalizedName: item.normalizedName,
                    categoryId: item.categoryId,
                    quantity: item.quantity,
                    unit: item.unit,
                    remainingPercentage: 100,
                    storageLocationId: item.storageLocationId,
                    purchaseDate: now,
                    expirationDate: item.estimatedExpirationDate,
                    createdAt: now,
                    updatedAt: now,
                  );

                  final updated = await context.push<InventoryItem>(
                    AppRouteNames.itemForm,
                    extra: dummyItem,
                  );

                  if (updated != null && mounted) {
                    final newReceiptItem = item.copyWith(
                      name: updated.name,
                      categoryId: updated.categoryId,
                      quantity: updated.quantity,
                      unit: updated.unit,
                      storageLocationId: updated.storageLocationId,
                      estimatedExpirationDate: updated.expirationDate,
                    );
                    scanNotifier.updateItem(index, newReceiptItem);
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

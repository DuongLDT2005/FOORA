import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/household_invitation.dart';
import '../providers/household_provider.dart';

class InviteMemberBottomSheet extends ConsumerStatefulWidget {
  final String householdId;
  final String householdName;

  const InviteMemberBottomSheet({
    super.key,
    required this.householdId,
    required this.householdName,
  });

  static Future<void> show(
    BuildContext context, {
    required String householdId,
    required String householdName,
  }) {
    return BottomSheetHelper.show<void>(
      context,
      title: 'Mời thành viên gia đình',
      child: InviteMemberBottomSheet(
        householdId: householdId,
        householdName: householdName,
      ),
    );
  }

  @override
  ConsumerState<InviteMemberBottomSheet> createState() =>
      _InviteMemberBottomSheetState();
}

class _InviteMemberBottomSheetState
    extends ConsumerState<InviteMemberBottomSheet> {
  bool _isGenerating = false;
  bool _isRevoking = false;

  Future<void> _generateNewInvitation() async {
    setState(() => _isGenerating = true);
    try {
      await ref
          .read(householdControllerProvider)
          .generateInvitation(widget.householdId);
      if (mounted) {
        ToastHelper.show(context, 'Đã tạo mã lời mời mới thành công!');
      }
    } on Failure catch (e) {
      if (mounted) {
        ToastHelper.show(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _revokeInvitation(String invitationId) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Thu hồi mã lời mời',
      message:
          'Bạn có chắc chắn muốn thu hồi mã này? Người nhận sẽ không thể sử dụng mã này để tham gia nữa.',
      confirmText: 'Thu hồi',
    );
    if (confirmed != true) return;

    setState(() => _isRevoking = true);
    try {
      await ref
          .read(householdControllerProvider)
          .revokeInvitation(widget.householdId, invitationId);
      if (mounted) {
        ToastHelper.show(context, 'Đã thu hồi mã lời mời.');
      }
    } on Failure catch (e) {
      if (mounted) {
        ToastHelper.show(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isRevoking = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ToastHelper.show(context, 'Đã sao chép $label vào bộ nhớ tạm.');
  }

  @override
  Widget build(BuildContext context) {
    final invitationAsync = ref.watch(
      activeHouseholdInvitationProvider(widget.householdId),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: invitationAsync.when(
        loading: () => SizedBox(
          height: 240.h,
          child: const LoadingWidget(message: 'Đang tải thông tin lời mời...'),
        ),
        error: (error, _) => Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: Column(
            children: [
              Text(
                'Không thể tải mã lời mời.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  color: AppColors.red600,
                ),
              ),
              SizedBox(height: 16.h),
              PrimaryButton(
                text: 'Thử lại',
                onPressed: () => ref.invalidate(
                  activeHouseholdInvitationProvider(widget.householdId),
                ),
              ),
            ],
          ),
        ),
        data: (invitation) {
          if (invitation == null) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Column(
                children: [
                  Container(
                    width: 64.r,
                    height: 64.r,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.userPlus,
                      size: 28.r,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Chưa có mã lời mời nào đang hoạt động',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Tạo mã mới để mời các thành viên tham gia gia đình "${widget.householdName}".',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      color: AppColors.slate500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  PrimaryButton(
                    text: 'Tạo mã lời mời ngay',
                    isLoading: _isGenerating,
                    onPressed: _generateNewInvitation,
                  ),
                ],
              ),
            );
          }

          return _buildActiveInvitationView(invitation);
        },
      ),
    );
  }

  Widget _buildActiveInvitationView(HouseholdInvitation invitation) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Code Card
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 180.r,
                height: 180.r,
                child: QrImageView(
                  data: invitation.code,
                  version: QrVersions.auto,
                  size: 180.r,
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Quét mã QR bằng ứng dụng FOORA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // Code Display & Copy Box
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MÃ THAM GIA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate400,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      invitation.code,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _copyToClipboard(invitation.code, 'mã tham gia'),
                child: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.copy,
                    size: 18.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // Expiration hint
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clock, size: 14.r, color: AppColors.slate400),
            SizedBox(width: 6.w),
            Text(
              'Hết hạn vào: ${DateFormatter.formatDate(invitation.expiresAt)}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),

        // Actions: Copy Link & Revoke
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(
                    invitation.shareUrl,
                    'liên kết tham gia',
                  ),
                  icon: Icon(LucideIcons.link, size: 16.r),
                  label: Text(
                    'Sao chép liên kết',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: _isRevoking
                    ? const Center(child: CircularProgressIndicator())
                    : OutlinedButton.icon(
                        onPressed: () => _revokeInvitation(invitation.id),
                        icon: Icon(
                          LucideIcons.ban,
                          size: 16.r,
                          color: AppColors.red500,
                        ),
                        label: Text(
                          'Thu hồi mã',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              AppColors.red500.withValues(alpha: 0.05),
                          side: BorderSide(
                            color: AppColors.red500.withValues(alpha: 0.2),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/household_invitation.dart';
import '../providers/household_provider.dart';
import 'household_seats_card.dart';

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

  Future<void> _regenerateInvitation() async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: 'Tạo mã mới',
      message:
          'Mã hiện tại sẽ hết hiệu lực ngay. Người chưa tham gia cần dùng mã mới.',
      confirmText: 'Tạo mã mới',
    );
    if (confirmed != true) return;
    await _generateNewInvitation();
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
    final household = ref.watch(currentHouseholdStreamProvider).valueOrNull;
    final memberCount = household?.id == widget.householdId
        ? household!.members.length
        : null;

    // AppBottomSheet already pads horizontally; only add vertical spacing.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (memberCount != null) ...[
            HouseholdSeatsCard(
              memberCount: memberCount,
              closeBeforeUpgrade: true,
            ),
            SizedBox(height: 16.h),
          ],
          _buildInvitationBody(invitationAsync),
        ],
      ),
    );
  }

  Widget _buildInvitationBody(
    AsyncValue<HouseholdInvitation?> invitationAsync,
  ) {
    return invitationAsync.when(
      loading: () => SizedBox(
        height: 240.h,
        child: const LoadingWidget(message: 'Đang tải thông tin lời mời...'),
      ),
      error: (error, _) => ErrorStateWidget(
        message: 'Không thể tải mã lời mời.',
        onRetry: () => ref.invalidate(
          activeHouseholdInvitationProvider(widget.householdId),
        ),
      ),
      data: (invitation) {
        if (invitation == null) {
          return EmptyStateWidget(
            icon: LucideIcons.userPlus,
            title: 'Chưa có mã lời mời nào đang hoạt động',
            subtitle:
                'Tạo mã mới để mời các thành viên tham gia gia đình "${widget.householdName}".',
            action: PrimaryButton(
              text: 'Tạo mã lời mời ngay',
              isLoading: _isGenerating,
              onPressed: _generateNewInvitation,
            ),
          );
        }

        return _buildActiveInvitationView(invitation);
      },
    );
  }

  Widget _buildActiveInvitationView(HouseholdInvitation invitation) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR encodes only the 6-character code; the join sheet scans it.
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            children: [
              QrImageView(
                data: invitation.code,
                version: QrVersions.auto,
                size: 180.r,
                backgroundColor: Colors.white,
              ),
              SizedBox(height: 8.h),
              Text(
                'Người được mời mở "Tham gia gia đình" → "Quét mã QR"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamilySans,
                  fontSize: 12.sp,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

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
                        fontFamily: AppTextStyles.fontFamilySans,
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
                        fontFamily: AppTextStyles.fontFamilyHeadline,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                tooltip: 'Sao chép mã',
                onPressed: () =>
                    _copyToClipboard(invitation.code, 'mã tham gia'),
                icon: Icon(LucideIcons.copy, size: 20.r),
                color: AppColors.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  minimumSize: Size(44.r, 44.r),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
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
                fontFamily: AppTextStyles.fontFamilySans,
                fontSize: 12.sp,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),

        // Stacked full-width actions: half-width buttons squeeze the labels
        // on narrow phones.
        AppButton.primary(
          label: 'Tạo mã mới',
          icon: LucideIcons.refreshCw,
          isLoading: _isGenerating,
          onPressed: _isRevoking ? null : _regenerateInvitation,
        ),
        SizedBox(height: 12.h),
        DangerButton(
          text: _isRevoking ? 'Đang thu hồi...' : 'Thu hồi mã',
          icon: LucideIcons.ban,
          onPressed: _isGenerating || _isRevoking
              ? null
              : () => _revokeInvitation(invitation.id),
        ),
      ],
    );
  }
}

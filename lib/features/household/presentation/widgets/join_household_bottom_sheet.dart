import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/household_invitation_info.dart';
import '../providers/household_provider.dart';

class JoinHouseholdBottomSheet extends ConsumerStatefulWidget {
  const JoinHouseholdBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return BottomSheetHelper.show<bool>(
      context,
      title: 'Tham gia gia đình',
      child: const JoinHouseholdBottomSheet(),
    );
  }

  @override
  ConsumerState<JoinHouseholdBottomSheet> createState() =>
      _JoinHouseholdBottomSheetState();
}

class _JoinHouseholdBottomSheetState
    extends ConsumerState<JoinHouseholdBottomSheet> {
  final _codeController = TextEditingController();
  HouseholdInvitationInfo? _previewInfo;
  bool _isChecking = false;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkInvitation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã lời mời.');
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _previewInfo = null;
    });

    try {
      final info = await ref
          .read(householdControllerProvider)
          .getInvitationInfo(code);
      if (mounted) {
        setState(() {
          _previewInfo = info;
        });
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _confirmJoin() async {
    final code = _previewInfo?.code ?? _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isJoining = true);
    try {
      await ref.read(householdControllerProvider).joinHousehold(code);
      if (mounted) {
        ToastHelper.show(
          context,
          'Chào mừng bạn gia nhập "${_previewInfo?.householdName ?? 'gia đình'}"!',
        );
        Navigator.of(context).pop(true);
      }
    } on Failure catch (e) {
      if (mounted) {
        ToastHelper.show(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nhập mã lời mời được chủ gia đình chia sẻ để cùng quản lý tủ lạnh.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              color: AppColors.slate500,
            ),
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'Mã lời mời',
            placeholder: 'VD: FOORA-AB12CD',
            controller: _codeController,
            prefixIcon: Icon(
              LucideIcons.keyRound,
              size: 18.r,
              color: AppColors.slate400,
            ),
            validator: (_) => _errorMessage,
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: 6.h),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                color: AppColors.red600,
              ),
            ),
          ],
          SizedBox(height: 16.h),

          if (_previewInfo == null) ...[
            PrimaryButton(
              text: 'Kiểm tra mã',
              isLoading: _isChecking,
              onPressed: _checkInvitation,
            ),
          ] else ...[
            // Preview card
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.home,
                          size: 20.r,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _previewInfo!.householdName,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate800,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Chủ hộ: ${_previewInfo!.ownerName} • ${_previewInfo!.memberCount} thành viên',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                color: AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_previewInfo!.alreadyMember) ...[
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.circleCheck,
                          size: 16.r,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Bạn đã là thành viên của gia đình này.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20.h),

            if (!_previewInfo!.alreadyMember)
              PrimaryButton(
                text: 'Xác nhận tham gia',
                isLoading: _isJoining,
                onPressed: _confirmJoin,
              ),
          ],
        ],
      ),
    );
  }
}

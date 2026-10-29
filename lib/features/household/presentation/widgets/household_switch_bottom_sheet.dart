import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/household.dart';
import '../providers/household_provider.dart';
import 'join_household_bottom_sheet.dart';

class HouseholdSwitchBottomSheet extends ConsumerStatefulWidget {
  const HouseholdSwitchBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BottomSheetHelper.show<void>(
      context,
      title: 'Chuyển đổi gia đình',
      child: const HouseholdSwitchBottomSheet(),
    );
  }

  @override
  ConsumerState<HouseholdSwitchBottomSheet> createState() =>
      _HouseholdSwitchBottomSheetState();
}

class _HouseholdSwitchBottomSheetState
    extends ConsumerState<HouseholdSwitchBottomSheet> {
  String? _switchingId;

  Future<void> _switch(Household household) async {
    final activeId = ref.read(currentUserProvider)?.activeHouseholdId;
    if (household.id == activeId) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _switchingId = household.id);
    try {
      await ref.read(householdControllerProvider).switchHousehold(household.id);
      if (mounted) {
        ToastHelper.show(
          context,
          'Đã chuyển sang tủ lạnh "${household.name}".',
        );
        Navigator.of(context).pop();
      }
    } on Failure catch (e) {
      if (mounted) {
        ToastHelper.show(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _switchingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdsAsync = ref.watch(userHouseholdsStreamProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final activeHouseholdId =
        ref.watch(currentUserProvider)?.activeHouseholdId ?? '';

    // AppBottomSheet already pads horizontally; only add vertical spacing.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          householdsAsync.when(
            loading: () => SizedBox(
              height: 140.h,
              child: const LoadingWidget(message: 'Đang tải danh sách...'),
            ),
            error: (err, _) => ErrorStateWidget(
              message: 'Không thể tải danh sách gia đình.',
              onRetry: () => ref.invalidate(userHouseholdsStreamProvider),
            ),
            data: (households) {
              if (households.isEmpty) {
                return const EmptyStateWidget(
                  icon: LucideIcons.home,
                  title: 'Bạn chưa tham gia gia đình nào',
                  subtitle:
                      'Nhập mã lời mời để dùng chung tủ lạnh với người thân.',
                );
              }

              return Column(
                children: households.map((h) {
                  final isActive = h.id == activeHouseholdId;
                  final isOwner = h.isOwner(currentUserId);
                  final isSwitchingThis = _switchingId == h.id;
                  final isLocked = h.isLockedMember(currentUserId);

                  final radius = BorderRadius.circular(14.r);
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Material(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: radius,
                        side: BorderSide(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.slate200,
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: radius,
                        onTap: _switchingId == null && !isLocked
                            ? () => _switch(h)
                            : null,
                        child: Padding(
                          padding: EdgeInsets.all(14.r),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary.withValues(
                                          alpha: 0.12,
                                        )
                                      : AppColors.slate100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.home,
                                  size: 18.r,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.slate600,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            h.name,
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTextStyles.fontFamilySans,
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.slate800,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isOwner) ...[
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 2.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              'Chủ hộ',
                                              style: TextStyle(
                                                fontFamily: AppTextStyles
                                                    .fontFamilySans,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 3.h),
                                    Text(
                                      isLocked
                                          ? 'Tạm khóa: chủ gia đình đã hết Premium'
                                          : '${h.members.length} thành viên • ${h.activeItemCount} thực phẩm',
                                      style: TextStyle(
                                        fontFamily:
                                            AppTextStyles.fontFamilySans,
                                        fontSize: 12.sp,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSwitchingThis)
                                const AppLoadingSpinner(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                )
                              else if (isLocked)
                                Icon(
                                  LucideIcons.lock,
                                  size: 20.r,
                                  color: AppColors.slate400,
                                )
                              else if (isActive)
                                Icon(
                                  LucideIcons.circleCheck,
                                  size: 22.r,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 16.h),
          PrimaryButton(
            text: 'Tham gia gia đình khác bằng mã',
            onPressed: () {
              // This sheet's context dies on pop; open the next sheet from
              // the navigator that is still mounted underneath.
              final navigator = Navigator.of(context);
              navigator.pop();
              JoinHouseholdBottomSheet.show(navigator.context);
            },
          ),
        ],
      ),
    );
  }
}

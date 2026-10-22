import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          householdsAsync.when(
            loading: () => SizedBox(
              height: 140.h,
              child: const LoadingWidget(message: 'Đang tải danh sách...'),
            ),
            error: (err, _) => Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Text(
                'Không thể tải danh sách gia đình.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  color: AppColors.red600,
                ),
              ),
            ),
            data: (households) {
              if (households.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Text(
                    'Bạn chưa tham gia gia đình nào.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      color: AppColors.slate500,
                    ),
                  ),
                );
              }

              return Column(
                children: households.map((h) {
                  final isActive = h.id == activeHouseholdId;
                  final isOwner = h.isOwner(currentUserId);
                  final isSwitchingThis = _switchingId == h.id;

                  return GestureDetector(
                    onTap: _switchingId == null ? () => _switch(h) : null,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.slate200,
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.12)
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
                                          fontFamily: 'Inter',
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate800,
                                        ),
                                        maxLines: 1,
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
                                          borderRadius: BorderRadius.circular(
                                            6.r,
                                          ),
                                        ),
                                        child: Text(
                                          'Chủ hộ',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
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
                                  '${h.members.length} thành viên • ${h.activeItemCount} thực phẩm',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.sp,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSwitchingThis)
                            SizedBox(
                              width: 20.r,
                              height: 20.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
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
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 16.h),
          PrimaryButton(
            text: 'Tham gia gia đình khác bằng mã',
            onPressed: () {
              Navigator.of(context).pop();
              JoinHouseholdBottomSheet.show(context);
            },
          ),
        ],
      ),
    );
  }
}

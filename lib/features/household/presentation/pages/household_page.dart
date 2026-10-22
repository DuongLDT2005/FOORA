import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_member.dart';
import '../providers/household_provider.dart';
import '../widgets/edit_household_name_dialog.dart';
import '../widgets/invite_dialog.dart';
import '../widgets/join_household_bottom_sheet.dart';
import '../widgets/household_seats_card.dart';
import '../widgets/household_switch_bottom_sheet.dart';
import '../widgets/member_list_item.dart';

class HouseholdPage extends ConsumerStatefulWidget {
  const HouseholdPage({super.key});

  @override
  ConsumerState<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends ConsumerState<HouseholdPage> {
  bool _isLeaving = false;

  Future<void> _onRemoveMember(
    Household household,
    HouseholdMember member,
  ) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa thành viên',
      message:
          'Bạn có chắc chắn muốn xóa "${member.fullName}" khỏi gia đình "${household.name}"?',
      confirmText: 'Xóa thành viên',
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(householdControllerProvider)
          .removeMember(household.id, member.id);
      if (mounted) {
        ToastHelper.show(context, 'Đã xóa ${member.fullName} khỏi gia đình.');
      }
    } on Failure catch (e) {
      if (mounted) {
        ToastHelper.show(context, e.message, isError: true);
      }
    }
  }

  Future<void> _onLeaveHousehold(Household household) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Rời khỏi gia đình',
      message:
          'Bạn có chắc chắn muốn rời khỏi gia đình "${household.name}"? Bạn sẽ mất quyền truy cập vào danh sách thực phẩm chung của gia đình này.',
      confirmText: 'Rời gia đình',
    );
    if (confirmed != true) return;

    setState(() => _isLeaving = true);
    try {
      await ref.read(householdControllerProvider).leaveHousehold(household.id);
      if (mounted) {
        ToastHelper.show(
          context,
          'Bạn đã rời khỏi gia đình "${household.name}".',
        );
      }
    } on Failure catch (e) {
      if (mounted) {
        ToastHelper.show(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentHouseholdAsync = ref.watch(currentHouseholdStreamProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return SubpageLayout(
      header: AppHeader(
        title: 'Quản lý gia đình',
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRouteNames.profile);
          }
        },
      ),
      body: currentHouseholdAsync.when(
        loading: () => SizedBox(
          height: 350.h,
          child: const LoadingWidget(message: 'Đang tải thông tin gia đình...'),
        ),
        error: (err, _) => ErrorStateWidget(
          message: 'Không thể tải thông tin gia đình.',
          onRetry: () => ref.invalidate(currentHouseholdStreamProvider),
        ),
        data: (household) {
          if (household == null) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
              child: Column(
                children: [
                  const EmptyStateWidget(
                    title: 'Chưa có thông tin gia đình',
                    subtitle:
                        'Bạn chưa thuộc gia đình nào hoặc tài khoản chưa kích hoạt gia đình.',
                  ),
                  SizedBox(height: 24.h),
                  PrimaryButton(
                    text: 'Tham gia bằng mã lời mời',
                    onPressed: () => JoinHouseholdBottomSheet.show(context),
                  ),
                ],
              ),
            );
          }

          final isOwner = household.isOwner(currentUserId);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Household Overview Card
                _buildOverviewCard(household, isOwner),
                SizedBox(height: 24.h),

                // 2. Members Section Header & List
                _buildMembersSection(household, isOwner),
                SizedBox(height: 24.h),

                // 3. Join Other Household Card
                _buildJoinOtherCard(),
                SizedBox(height: 24.h),

                // 4. Leave Household Action (Only for non-owner members)
                if (!isOwner) ...[
                  _isLeaving
                      ? const Center(
                          child: AppLoadingSpinner(
                            size: 28,
                            color: AppColors.red500,
                          ),
                        )
                      : DangerButton(
                          text: 'Rời khỏi gia đình này',
                          icon: LucideIcons.logOut,
                          onPressed: () => _onLeaveHousehold(household),
                        ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.shieldCheck,
                          size: 20.r,
                          color: AppColors.emerald700,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Bạn là Chủ sở hữu của gia đình này. Bạn có toàn quyền quản lý thành viên và tạo mã lời mời.',
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontFamilySans,
                              fontSize: 12.sp,
                              color: AppColors.slate600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(Household household, bool isOwner) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.home, size: 14.r, color: Colors.white),
                    SizedBox(width: 6.w),
                    Text(
                      isOwner ? 'Gia đình bạn sở hữu' : 'Gia đình đã tham gia',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamilySans,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Switch household button
              _PillAction(
                icon: LucideIcons.arrowLeftRight,
                label: 'Đổi gia đình',
                foreground: AppColors.primary,
                background: AppColors.surfaceContainerLowest,
                onTap: () => HouseholdSwitchBottomSheet.show(context),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Name and Edit Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  household.name,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilyHeadline,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: Icon(
                    LucideIcons.pencil,
                    size: 18.r,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  tooltip: 'Đổi tên gia đình',
                  onPressed: () => EditHouseholdNameDialog.show(
                    context,
                    householdId: household.id,
                    currentName: household.name,
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),

          // Counters Row
          Row(
            children: [
              _buildCounterChip(
                icon: LucideIcons.users,
                label: '${household.members.length} thành viên',
              ),
              SizedBox(width: 10.w),
              _buildCounterChip(
                icon: LucideIcons.refrigerator,
                label: '${household.activeItemCount} món trong tủ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamilySans,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(Household household, bool isOwner) {
    final membersAsync = ref.watch(householdMembersProvider(household.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'THÀNH VIÊN GIA ĐÌNH',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamilySans,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
                letterSpacing: 0.8,
              ),
            ),
            if (isOwner)
              _PillAction(
                icon: LucideIcons.userPlus,
                label: 'Mời thành viên',
                foreground: AppColors.primary,
                background: AppColors.primary.withValues(alpha: 0.08),
                borderColor: AppColors.primary.withValues(alpha: 0.2),
                onTap: () => InviteMemberBottomSheet.show(
                  context,
                  householdId: household.id,
                  householdName: household.name,
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        if (isOwner) ...[
          HouseholdSeatsCard(memberCount: household.members.length),
          SizedBox(height: 12.h),
        ],

        membersAsync.when(
          loading: () => SizedBox(
            height: 120.h,
            child: const LoadingWidget(
              message: 'Đang tải danh sách thành viên...',
            ),
          ),
          error: (err, _) => ErrorStateWidget(
            message: 'Không thể tải thành viên gia đình.',
            onRetry: () =>
                ref.invalidate(householdMembersProvider(household.id)),
          ),
          data: (members) {
            if (members.isEmpty) {
              return const EmptyStateWidget(
                title: 'Chưa có thành viên nào',
                subtitle:
                    'Mời các thành viên trong gia đình để cùng chia sẻ tủ lạnh.',
              );
            }

            return Column(
              children: members
                  .map(
                    (m) => MemberListItem(
                      member: m,
                      canRemove: isOwner,
                      onRemove: () => _onRemoveMember(household, m),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildJoinOtherCard() {
    final radius = BorderRadius.circular(16.r);
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => JoinHouseholdBottomSheet.show(context),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.slate100),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.keyRound,
                  size: 20.r,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn có mã lời mời?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Nhập mã hoặc quét QR từ người thân để dùng chung tủ lạnh.',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                LucideIcons.chevronRight,
                size: 20.r,
                color: AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill action with a mobile-friendly (44px) touch target and ink
/// feedback, used for secondary header actions on this page.
class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22.r);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 44.h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15.r, color: foreground),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

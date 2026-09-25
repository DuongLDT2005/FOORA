import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../membership/domain/entities/membership_plan.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../receipt/presentation/providers/receipt_scan_provider.dart';
import '../../domain/entities/profile.dart';
import '../providers/profile_provider.dart';

class MyMembershipPage extends ConsumerStatefulWidget {
  const MyMembershipPage({super.key});

  @override
  ConsumerState<MyMembershipPage> createState() => _MyMembershipPageState();
}

class _MyMembershipPageState extends ConsumerState<MyMembershipPage> {
  static const bool _autoRenew = false;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouteNames.profile);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileStreamProvider);

    return profileAsync.when(
      loading: () => _loadingPage(false),
      error: (error, _) => _errorPage(false, error),
      data: (profile) {
        if (profile == null) return _missingProfilePage();

        final planAsync = ref.watch(
          membershipPlanProvider(profile.membershipId),
        );
        final premiumPlanAsync = profile.isPremium
            ? planAsync
            : ref.watch(membershipPlanProvider('premium'));

        return planAsync.when(
          loading: () => _loadingPage(profile.isPremium),
          error: (error, _) => _errorPage(profile.isPremium, error),
          data: (plan) {
            final inventoryAsync = ref.watch(
              activeHouseholdInventoryStreamProvider,
            );
            final quotaAsync = ref.watch(receiptQuotaProvider);
            final foodCount = inventoryAsync.valueOrNull?.length ?? 0;
            final scansUsed = quotaAsync.valueOrNull?.scansUsed ?? 0;

            return profile.isPremium
                ? _buildPremiumPage(profile: profile, plan: plan)
                : _buildFreePage(
                    plan: plan,
                    premiumPlan: premiumPlanAsync.valueOrNull,
                    foodCount: foodCount,
                    scansUsed: scansUsed,
                  );
          },
        );
      },
    );
  }

  Widget _buildFreePage({
    required MembershipPlan plan,
    required MembershipPlan? premiumPlan,
    required int foodCount,
    required int scansUsed,
  }) {
    final foodLimit = plan.foodLimit ?? 30;
    final scanLimit = plan.receiptScanQuota ?? 5;
    final premiumPrice = premiumPlan?.price ?? 29000.0;

    return SubpageLayout(
      header: AppHeader.membership(onBack: _handleBack, isPremium: false),
      bottomNavigationBar: _FreeFooter(
        price: premiumPrice,
        onUpgrade: () => context.push(AppRouteNames.membership),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CurrentPlanCard(isPremium: false),
            SizedBox(height: 16.h),
            _QuotaProgressCard(
              icon: LucideIcons.refrigerator,
              iconColor: AppColors.primary,
              title: 'Số lượng thực phẩm',
              used: foodCount,
              limit: foodLimit,
              unit: 'món',
              description:
                  'Bạn đã dùng $foodCount/$foodLimit hạn mức lưu trữ thực phẩm',
            ),
            SizedBox(height: 16.h),
            _QuotaProgressCard(
              icon: LucideIcons.sparkles,
              iconColor: AppColors.amber500,
              title: 'Hạn mức quét hóa đơn',
              used: scansUsed,
              limit: scanLimit,
              unit: 'lượt',
              description:
                  'Bạn đã dùng $scansUsed/$scanLimit lượt quét hóa đơn tháng này',
            ),
            SizedBox(height: 24.h),
            const _SectionLabel('FREE BAO GỒM'),
            SizedBox(height: 12.h),
            const _FreeBenefitsCard(),
            SizedBox(height: 24.h),
            const _SectionLabel('PREMIUM CÓ GÌ KHÁC?'),
            SizedBox(height: 12.h),
            const _PremiumBenefits(),
            SizedBox(height: 24.h),
            const _SectionLabel('SO SÁNH GÓI'),
            SizedBox(height: 12.h),
            _PlanComparisonCard(
              freeFoodLimit: foodLimit,
              freeScanLimit: scanLimit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPage({
    required Profile profile,
    required MembershipPlan plan,
  }) {
    final startDate = profile.updatedAt;
    final renewalDate = startDate.add(Duration(days: plan.durationDays ?? 30));

    return SubpageLayout(
      header: AppHeader.membership(onBack: _handleBack, isPremium: true),
      bottomNavigationBar: _PremiumFooter(
        onManage: () => context.push(AppRouteNames.paymentHistory),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CurrentPlanCard(isPremium: true),
            SizedBox(height: 24.h),
            const _UnlimitedScanCard(),
            SizedBox(height: 24.h),
            _PackageInfoCard(
              startDate: startDate,
              renewalDate: renewalDate,
              autoRenew: _autoRenew,
              onAutoRenewChanged: null,
            ),
            SizedBox(height: 24.h),
            const _SectionLabel('QUYỀN LỢI PREMIUM'),
            SizedBox(height: 12.h),
            const _PremiumBenefits(),
          ],
        ),
      ),
    );
  }

  Widget _loadingPage(bool isPremium) {
    return SubpageLayout(
      header: AppHeader.membership(onBack: _handleBack, isPremium: isPremium),
      body: const Center(
        child: LoadingWidget(message: 'Đang tải thông tin gói...'),
      ),
    );
  }

  Widget _errorPage(bool isPremium, Object error) {
    return SubpageLayout(
      header: AppHeader.membership(onBack: _handleBack, isPremium: isPremium),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Text(
            'Không thể tải gói thành viên: $error',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.red600),
          ),
        ),
      ),
    );
  }

  Widget _missingProfilePage() {
    return SubpageLayout(
      header: AppHeader.membership(onBack: _handleBack),
      body: const Center(child: Text('Không tìm thấy hồ sơ người dùng.')),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isPremium ? AppColors.primary : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isPremium)
            Positioned(
              right: -22.w,
              bottom: -26.h,
              child: Icon(
                LucideIcons.sparkles,
                size: 112.r,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GÓI HIỆN TẠI',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.slate400,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                isPremium ? 'Premium' : 'Free',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: isPremium ? Colors.white : AppColors.slate800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isPremium
                    ? 'Bạn đang sử dụng gói Premium với tính năng quét hóa đơn không giới hạn.'
                    : 'Sử dụng các tính năng quản lý thực phẩm cốt lõi của FOORA với 5 lượt quét hóa đơn mỗi tháng.',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13.sp,
                  height: 1.45,
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaProgressCard extends StatelessWidget {
  const _QuotaProgressCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.used,
    required this.limit,
    required this.unit,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final int used;
  final int limit;
  final String unit;
  final String description;

  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return _WhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16.r, color: iconColor),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              Text(
                '$used/$limit $unit',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10.h,
              value: progress,
              backgroundColor: AppColors.slate100,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlimitedScanCard extends StatelessWidget {
  const _UnlimitedScanCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16.r, color: AppColors.amber500),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Hạn mức quét hóa đơn',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Không giới hạn',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.amber600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.amber50.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.amber200.withValues(alpha: 0.65),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.sparkles,
                  size: 16.r,
                  color: AppColors.amber600,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quét hóa đơn thả ga',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber800,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Thoải mái thêm thực phẩm tự động bằng công nghệ nhận diện hình ảnh với gói Premium.',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 12.sp,
                          color: AppColors.amber800.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageInfoCard extends StatelessWidget {
  const _PackageInfoCard({
    required this.startDate,
    required this.renewalDate,
    required this.autoRenew,
    required this.onAutoRenewChanged,
  });

  final DateTime startDate;
  final DateTime renewalDate;
  final bool autoRenew;
  final ValueChanged<bool>? onAutoRenewChanged;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');

    return _WhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.calendarDays,
                size: 16.r,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Thông tin gói',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          const _InfoRow(
            label: 'Gói đăng ký',
            value: 'FOORA Premium',
            bold: true,
          ),
          _InfoRow(label: 'Ngày bắt đầu', value: formatter.format(startDate)),
          _InfoRow(label: 'Ngày gia hạn', value: formatter.format(renewalDate)),
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tự động gia hạn',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: autoRenew,
                  activeTrackColor: AppColors.primary,
                  onChanged: onAutoRenewChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13.sp,
                color: AppColors.slate500,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 14.sp,
              color: AppColors.slate800,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeBenefitsCard extends StatelessWidget {
  const _FreeBenefitsCard();

  static const benefits = [
    'Quản lý tối đa 30 thực phẩm',
    'Theo dõi số lượng và đơn vị',
    'Theo dõi hạn sử dụng',
    'Quản lý ngăn mát và ngăn đông',
    'Thêm thực phẩm thủ công',
    'Quét hóa đơn (Giới hạn 5 lần/tháng)',
    'Nhận thông báo hết hạn',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.slate100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(benefits.length, (index) {
          return Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              border: index == benefits.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.slate50)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28.r,
                  height: 28.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.check,
                    size: 16.r,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    benefits[index],
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _PremiumBenefits extends StatelessWidget {
  const _PremiumBenefits();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _BenefitCard(
          icon: LucideIcons.check,
          title: 'Lưu trữ thực phẩm không giới hạn',
          description:
              'Thêm bao nhiêu thực phẩm tuỳ thích mà không lo đầy kho lưu trữ.',
        ),
        SizedBox(height: 12),
        _BenefitCard(
          icon: LucideIcons.sparkles,
          title: 'Quét hóa đơn không giới hạn',
          description:
              'Tự động nhận diện không giới hạn số lượng hóa đơn mua sắm.',
        ),
        SizedBox(height: 12),
        _BenefitCard(
          icon: LucideIcons.sparkles,
          title: 'Tất cả tính năng của gói Free',
          description: 'Bao gồm thông báo hết hạn, quản lý các ngăn chứa,...',
        ),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: EdgeInsets.all(16.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: AppColors.amber50,
              borderRadius: BorderRadius.circular(16.r),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20.r, color: AppColors.amber600),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontFamily: AppTextStyles.fontFamilyHeadline,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanComparisonCard extends StatelessWidget {
  const _PlanComparisonCard({
    required this.freeFoodLimit,
    required this.freeScanLimit,
  });

  final int freeFoodLimit;
  final int freeScanLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.slate100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.slate50,
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
            child: const Row(
              children: [
                Expanded(child: SizedBox()),
                Expanded(child: _ComparisonHeading('FREE')),
                Expanded(child: _ComparisonHeading('PREMIUM', premium: true)),
              ],
            ),
          ),
          _ComparisonRow(
            label: 'Quản lý thực phẩm',
            freeValue: 'Tối đa $freeFoodLimit',
            premiumIcon: LucideIcons.infinity,
          ),
          const _ComparisonRow(
            label: 'Theo dõi hạn sử dụng',
            freeIcon: LucideIcons.check,
            premiumIcon: LucideIcons.check,
          ),
          const _ComparisonRow(
            label: 'Thông báo hết hạn',
            freeIcon: LucideIcons.check,
            premiumIcon: LucideIcons.check,
          ),
          _ComparisonRow(
            label: 'Quét hóa đơn',
            freeValue: '$freeScanLimit lượt/tháng',
            premiumIcon: LucideIcons.infinity,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonHeading extends StatelessWidget {
  const _ComparisonHeading(this.text, {this.premium = false});

  final String text;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.copyWith(
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        color: premium ? AppColors.amber600 : AppColors.slate500,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    this.freeValue,
    this.freeIcon,
    required this.premiumIcon,
    this.last = false,
  });

  final String label;
  final String? freeValue;
  final IconData? freeIcon;
  final IconData premiumIcon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.slate50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.slate600,
              ),
            ),
          ),
          Expanded(
            child: freeIcon != null
                ? Icon(freeIcon, size: 17.r, color: AppColors.primary)
                : Text(
                    freeValue ?? '',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate500,
                    ),
                  ),
          ),
          Expanded(
            child: Icon(premiumIcon, size: 18.r, color: AppColors.amber500),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.slate400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.025),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FreeFooter extends StatelessWidget {
  const _FreeFooter({required this.price, required this.onUpgrade});

  final double price;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final formattedPrice = '${NumberFormat('#,##0', 'vi_VN').format(price)}đ';

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GÓI PREMIUM',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 11.sp,
                color: AppColors.slate400,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedPrice,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate800,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h, left: 4.w),
                  child: Text(
                    '/ tháng',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'Nâng cấp Premium',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontFamily: AppTextStyles.fontFamilyHeadline,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumFooter extends StatelessWidget {
  const _PremiumFooter({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56.h,
          child: OutlinedButton(
            onPressed: onManage,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.slate100,
              foregroundColor: AppColors.slate700,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Quản lý gói',
              style: AppTextStyles.bodyMedium.copyWith(
                fontFamily: AppTextStyles.fontFamilyHeadline,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

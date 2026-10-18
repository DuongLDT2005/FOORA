import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'membership_cards.dart';

/// List of what the Free plan includes.
class FreeBenefitsCard extends StatelessWidget {
  const FreeBenefitsCard({
    super.key,
    required this.foodLimit,
    required this.scanLimit,
  });

  /// Limits of the Free plan from `memberships/free`; `null` = unlimited.
  final int? foodLimit;
  final int? scanLimit;

  @override
  Widget build(BuildContext context) {
    final benefits = [
      foodLimit == null
          ? 'Quản lý thực phẩm không giới hạn'
          : 'Quản lý tối đa $foodLimit thực phẩm',
      'Theo dõi số lượng và đơn vị',
      'Theo dõi hạn sử dụng',
      'Quản lý ngăn mát và ngăn đông',
      'Thêm thực phẩm thủ công',
      scanLimit == null
          ? 'Quét hóa đơn không giới hạn'
          : 'Quét hóa đơn (Giới hạn $scanLimit lần/tháng)',
      'Nhận thông báo hết hạn',
    ];

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

/// Grid of Premium benefits.
class PremiumBenefitsList extends StatelessWidget {
  const PremiumBenefitsList({super.key});

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

/// One benefit item (icon, title, description).
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
    return MembershipWhiteCard(
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

/// Free vs. Premium comparison table.
class PlanComparisonCard extends StatelessWidget {
  const PlanComparisonCard({
    super.key,
    required this.freeFoodLimit,
    required this.freeScanLimit,
  });

  /// Free-plan limits from Firestore; `null` = unlimited.
  final int? freeFoodLimit;
  final int? freeScanLimit;

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
            freeValue: freeFoodLimit == null ? null : 'Tối đa $freeFoodLimit',
            freeIcon: freeFoodLimit == null ? LucideIcons.infinity : null,
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
            freeValue: freeScanLimit == null
                ? null
                : '$freeScanLimit lượt/tháng',
            freeIcon: freeScanLimit == null ? LucideIcons.infinity : null,
            premiumIcon: LucideIcons.infinity,
            last: true,
          ),
        ],
      ),
    );
  }
}

/// Column headings of the comparison table.
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

/// One feature row of the comparison table.
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

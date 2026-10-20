import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/waste_statistics.dart';
import '../../../inventory/presentation/widgets/food_image_avatar.dart';

/// Ranked list of the top-5 most discarded foods with progress bars.
class TopWastedFoodsList extends StatelessWidget {
  const TopWastedFoodsList({super.key, required this.topWasted});

  final List<TopWastedFood> topWasted;

  @override
  Widget build(BuildContext context) {
    if (topWasted.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hay bị vứt nhất',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.slate700,
              ),
            ),
            SizedBox(height: 12.h),
            ...topWasted.asMap().entries.map((e) {
              final rank = e.key + 1;
              final food = e.value;
              return _TopFoodRow(rank: rank, food: food);
            }),
          ],
        ),
      ),
    );
  }
}

class _TopFoodRow extends StatelessWidget {
  const _TopFoodRow({required this.rank, required this.food});

  final int rank;
  final TopWastedFood food;

  @override
  Widget build(BuildContext context) {
    final pct = food.percentOfDiscarded;
    final rankColors = [
      AppColors.amber500,
      AppColors.slate400,
      AppColors.amber700,
      AppColors.slate300,
      AppColors.slate300,
    ];
    final rankColor = rank <= rankColors.length
        ? rankColors[rank - 1]
        : AppColors.slate300;

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 24.r,
            height: 24.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w900,
                color: rankColor,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          // Food avatar
          FoodImageAvatar(
            categoryId: food.categoryId,
            size: 36,
            borderRadius: 10,
          ),
          SizedBox(width: 10.w),
          // Name + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${food.count} lần · ${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5.h,
                    backgroundColor: AppColors.red50,
                    color: AppColors.red500,
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

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/inventory_item.dart';

/// Alert banner shown when duplicate/similar item is detected in inventory
class SmartInventoryAlertBanner extends StatelessWidget {
  final InventoryItem item;

  const SmartInventoryAlertBanner({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final expFormatted = DateFormatter.formatDate(item.expirationDate);

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // amber-50
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFEF3C7)), // amber-100
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'KHO SẴN CÓ',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFB45309), // amber-700
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12.5.sp,
                color: const Color(0xFF92400E),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
              children: [
                const TextSpan(text: 'Bạn hiện có '),
                TextSpan(
                  text: '${item.quantity} ${item.unit} ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: 'của "'),
                TextSpan(
                  text: item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      '" trong tủ lạnh (HSD còn tới $expFormatted, lượng còn ${item.remainingPercentage}%). Để tránh lãng phí, vui lòng cân nhắc trước khi mua thêm!',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

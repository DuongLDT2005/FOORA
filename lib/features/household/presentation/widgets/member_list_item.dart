import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/household_member.dart';

class MemberListItem extends StatelessWidget {
  final HouseholdMember member;
  final bool canRemove;
  final VoidCallback? onRemove;

  const MemberListItem({
    super.key,
    required this.member,
    this.canRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: member.isOwner
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.slate100,
              border: Border.all(
                color: member.isOwner
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : AppColors.slate200,
                width: 1.5,
              ),
              image: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(member.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: member.avatarUrl == null || member.avatarUrl!.isEmpty
                ? Text(
                    member.initials,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: member.isOwner
                          ? AppColors.primary
                          : AppColors.slate600,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 14.w),

          // Name, Email & Role Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
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
                    if (member.isCurrentUser) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'Bạn',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: member.isOwner
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: member.isOwner
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.slate200,
                        ),
                      ),
                      child: Text(
                        member.isOwner ? 'Chủ gia đình' : 'Thành viên',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: member.isOwner
                              ? AppColors.primary
                              : AppColors.slate600,
                        ),
                      ),
                    ),
                    if (member.email.isNotEmpty) ...[
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          member.email,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            color: AppColors.slate400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Remove Button (Owner only, not self)
          if (canRemove && !member.isOwner && !member.isCurrentUser)
            IconButton(
              icon: Icon(
                LucideIcons.userMinus,
                size: 20.r,
                color: AppColors.red500,
              ),
              tooltip: 'Xóa thành viên',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

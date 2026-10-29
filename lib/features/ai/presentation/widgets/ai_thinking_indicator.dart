import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Waiting row whose text changes over time. Most answers take 1-2 s; when
/// the backend falls back to another model the wait can reach 10 s, and a
/// changing message shows the app has not frozen.
class AiThinkingIndicator extends StatefulWidget {
  const AiThinkingIndicator({super.key});

  static const stages = [
    (after: Duration.zero, text: 'FOORA đang trả lời…'),
    (after: Duration(seconds: 3), text: 'Đang soạn câu trả lời, chờ chút nhé…'),
    (
      after: Duration(seconds: 10),
      text: 'Dịch vụ AI hơi chậm, FOORA vẫn đang thử…',
    ),
  ];

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator> {
  final List<Timer> _timers = [];
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    for (var index = 1; index < AiThinkingIndicator.stages.length; index++) {
      _timers.add(
        Timer(AiThinkingIndicator.stages[index].after, () {
          if (mounted) setState(() => _stage = index);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16.r,
              height: 16.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10.w),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  AiThinkingIndicator.stages[_stage].text,
                  key: ValueKey(_stage),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate600,
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

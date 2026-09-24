import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../helpers/debouncer.dart';

class AppSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final Duration debounceDuration;
  final bool autoFocus;

  const AppSearchBar({
    super.key,
    this.hintText = 'Tìm kiếm thực phẩm, danh mục...',
    this.onChanged,
    this.onClear,
    this.controller,
    this.debounceDuration = const Duration(milliseconds: 350),
    this.autoFocus = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final Debouncer _debouncer;
  bool _hasText = false;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer(delay: widget.debounceDuration);
    if (widget.controller == null) {
      _controller = TextEditingController();
      _isInternalController = true;
    } else {
      _controller = widget.controller!;
    }
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.removeListener(_handleTextChange);
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.slate100),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autoFocus,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.slate800,
        ),
        onChanged: (text) {
          _debouncer.run(() {
            widget.onChanged?.call(text);
          });
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 14.sp,
            color: AppColors.slate400,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.search, color: AppColors.slate400, size: 22.r),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(
                    Icons.cancel,
                    color: AppColors.slate400,
                    size: 18.r,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear?.call();
                    widget.onChanged?.call('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }
}

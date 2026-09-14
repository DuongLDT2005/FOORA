import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/toast_helper.dart';

extension ContextExtensions on BuildContext {
  // Theme & Colors
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;

  // Media Query & Screen Dimensions
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenHeight => MediaQuery.sizeOf(this).height;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);
  EdgeInsets get padding => MediaQuery.paddingOf(this);

  // Responsive Breakpoints
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;
  bool get isWebPlatform => kIsWeb;

  // Quick Feedback Toast
  void showToast(String message, {bool isError = false}) {
    ToastHelper.show(this, message, isError: isError);
  }
}

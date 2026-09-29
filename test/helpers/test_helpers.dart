import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget makeTestableWidget(Widget child, {Size size = const Size(390, 844)}) {
  return ScreenUtilInit(
    designSize: size,
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
  );
}

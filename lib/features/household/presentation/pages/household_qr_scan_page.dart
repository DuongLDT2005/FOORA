import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/household_provider.dart';
import '../utils/qr_image_decoder.dart';

/// Full-screen camera scanner for household invite QR codes.
///
/// Pops with the normalized 6-character code, or `null` when cancelled.
/// On the web mobile_scanner cannot decode picked images, so gallery images
/// go through the browser's `BarcodeDetector` (hidden when unsupported), and
/// the torch button is hidden because browsers rarely expose it.
/// Opened with `Navigator.push` from the join bottom sheet so the sheet stays
/// underneath and receives the result.
class HouseholdQrScanPage extends ConsumerStatefulWidget {
  const HouseholdQrScanPage({super.key});

  static Future<String?> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const HouseholdQrScanPage()),
    );
  }

  @override
  ConsumerState<HouseholdQrScanPage> createState() =>
      _HouseholdQrScanPageState();
}

class _HouseholdQrScanPageState extends ConsumerState<HouseholdQrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final ImagePicker _picker = ImagePicker();
  bool _handled = false;
  bool _decodingImage = false;
  String? _lastInvalidValue;

  /// Native platforms always decode via mobile_scanner; browsers need
  /// `BarcodeDetector` (Chrome/Edge 83+, Safari 17+, not Firefox).
  bool get _canPickImage => !kIsWeb || isWebQrImageDecodingSupported;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns the first raw value that is a valid invite code, if any.
  String? _firstInviteCode(Iterable<String?> rawValues) {
    final validate = ref.read(validateInviteCodeUseCaseProvider);
    for (final raw in rawValues) {
      if (raw == null) continue;
      final code = validate(raw);
      if (code != null) return code;
    }
    return null;
  }

  String? _extractCode(BarcodeCapture? capture) => _firstInviteCode(
    (capture?.barcodes ?? const <Barcode>[]).map((b) => b.rawValue),
  );

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = _extractCode(capture);
    if (code != null) {
      _finish(code);
      return;
    }
    // Warn once per foreign QR instead of on every camera frame.
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw != _lastInvalidValue) {
      _lastInvalidValue = raw;
      ToastHelper.show(
        context,
        'Mã QR này không phải mã mời gia đình FOORA.',
        isError: true,
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _decodingImage = true);
    String? code;
    try {
      if (kIsWeb) {
        final values = await decodeQrFromImageBytes(await image.readAsBytes());
        code = _firstInviteCode(values);
      } else {
        final capture = await _controller.analyzeImage(
          image.path,
          formats: const [BarcodeFormat.qrCode],
        );
        code = _extractCode(capture);
      }
    } catch (_) {
      // Unreadable image or detector failure: same message as "no code".
      code = null;
    } finally {
      if (mounted) setState(() => _decodingImage = false);
    }
    if (!mounted) return;

    if (code == null) {
      ToastHelper.show(
        context,
        'Không tìm thấy mã mời FOORA trong ảnh đã chọn.',
        isError: true,
      );
      return;
    }
    _finish(code);
  }

  void _finish(String code) {
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the scan window inside narrow phone browsers.
    final windowSize = (MediaQuery.sizeOf(context).width * 0.7).clamp(
      180.0,
      280.0,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Quét mã mời',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamilyHeadline,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Bật/tắt đèn',
              icon: Icon(LucideIcons.flashlight, size: 22.r),
              onPressed: () => _controller.toggleTorch(),
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraErrorView(
              permissionDenied:
                  error.errorCode == MobileScannerErrorCode.permissionDenied,
              canPickImage: _canPickImage,
            ),
          ),
          Center(
            child: Container(
              width: windowSize,
              height: windowSize,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.emerald500, width: 3),
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),
          Positioned(
            left: 24.w,
            right: 24.w,
            bottom: 40.h,
            child: Column(
              children: [
                Text(
                  'Đưa mã QR trong mục "Mời thành viên" của chủ gia đình vào khung',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 14.sp,
                    color: Colors.white,
                  ),
                ),
                if (_canPickImage) ...[
                  SizedBox(height: 16.h),
                  OutlinedButton.icon(
                    onPressed: _decodingImage ? null : _pickFromGallery,
                    icon: Icon(LucideIcons.image, size: 18.r),
                    label: AppButtonLabel(
                      _decodingImage
                          ? 'Đang đọc ảnh...'
                          : 'Chọn ảnh QR từ thư viện',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamilySans,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // The app theme gives outlined buttons a light slate fill,
                    // which hid the white label; use a dark translucent fill
                    // that stays readable over any camera frame.
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.slate900.withValues(
                        alpha: 0.6,
                      ),
                      foregroundColor: AppColors.surfaceContainerLowest,
                      disabledBackgroundColor: AppColors.slate900.withValues(
                        alpha: 0.4,
                      ),
                      disabledForegroundColor: AppColors.slate300,
                      side: BorderSide(
                        color: AppColors.surfaceContainerLowest.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      minimumSize: Size(0, 48.h),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the camera cannot start (usually a denied permission).
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.permissionDenied,
    required this.canPickImage,
  });

  final bool permissionDenied;
  final bool canPickImage;

  String _reason() {
    if (!permissionDenied) return 'Không thể mở camera.';
    return kIsWeb
        ? 'Trình duyệt chưa được cấp quyền Camera cho trang này.'
        : 'FOORA chưa được cấp quyền Camera. Hãy bật quyền trong Cài đặt.';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cameraOff, size: 40.r, color: Colors.white70),
              SizedBox(height: 12.h),
              Text(
                '${_reason()} ${canPickImage ? 'Bạn vẫn có thể chọn ảnh QR từ thư viện.' : 'Hãy nhập mã 6 ký tự thay thế.'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamilySans,
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

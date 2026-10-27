import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// Base class for all exceptions thrown by the data layer.
/// Repositories catch these and convert them into [Failure]s for the UI.
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// Thrown when a Firestore / Cloud Functions / Storage call fails on the server side.
class ServerException extends AppException {
  const ServerException([
    super.message = 'Đã xảy ra lỗi máy chủ. Vui lòng thử lại sau.',
    super.code,
  ]);

  /// Maps a [FirebaseException] code to a user-friendly Vietnamese message.
  factory ServerException.fromFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return ServerException(
          'Bạn không có quyền truy cập dữ liệu này.',
          e.code,
        );
      case 'not-found':
        return ServerException('Không tìm thấy dữ liệu yêu cầu.', e.code);
      case 'unavailable':
        return ServerException(
          'Dịch vụ máy chủ tạm thời gián đoạn. Vui lòng kiểm tra kết nối mạng.',
          e.code,
        );
      default:
        return ServerException(
          e.message ?? 'Đã xảy ra lỗi cơ sở dữ liệu.',
          e.code,
        );
    }
  }
}

/// Thrown when a Firebase Authentication operation fails (login, register, reset...).
class AuthException extends AppException {
  const AuthException([
    super.message = 'Xác thực không thành công.',
    super.code,
  ]);

  /// Translates Firebase Auth error codes (wrong-password, email-already-in-use, ...)
  /// into readable messages shown to the user.
  factory AuthException.fromFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthException(
          'Không tìm thấy tài khoản với email này.',
          'user-not-found',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException(
          'Email hoặc mật khẩu không chính xác.',
          'invalid-credential',
        );
      case 'email-already-in-use':
        return const AuthException(
          'Email này đã được sử dụng bởi một tài khoản khác.',
          'email-already-in-use',
        );
      case 'weak-password':
        return const AuthException(
          'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn.',
          'weak-password',
        );
      case 'user-disabled':
        return const AuthException(
          'Tài khoản này đã bị vô hiệu hóa hoặc khóa.',
          'user-disabled',
        );
      case 'too-many-requests':
        return const AuthException(
          'Quá nhiều lần thử thất bại. Vui lòng thử lại sau ít phút.',
          'too-many-requests',
        );
      case 'network-request-failed':
        return const AuthException(
          'Không thể kết nối mạng. Vui lòng kiểm tra lại kết nối Internet của bạn.',
          'network-request-failed',
        );
      default:
        return AuthException(
          e.message != null &&
                  !e.message!.contains('Exception') &&
                  !e.message!.contains('com.google')
              ? e.message!
              : 'Đăng nhập/xác thực thất bại. Vui lòng thử lại.',
          e.code,
        );
    }
  }
}

/// Thrown when the device has no internet connection or the request timed out.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại Wifi/4G.',
    super.code,
  ]);
}

/// Thrown when reading/writing local storage (SharedPreferences) fails.
class CacheException extends AppException {
  const CacheException([
    super.message = 'Lỗi truy xuất bộ nhớ tạm.',
    super.code,
  ]);
}

/// Thrown when a requested document does not exist.
class NotFoundException extends AppException {
  const NotFoundException([
    super.message = 'Không tìm thấy tài nguyên yêu cầu.',
    super.code,
  ]);
}

/// Thrown when Firestore security rules reject the current user's request.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'Bạn không có quyền thực hiện thao tác này.',
    super.code,
  ]);
}

enum LocationErrorCode { serviceDisabled, denied, deniedForever, timeout }

/// A device-location error that presentation can map to a recovery action.
class LocationException extends AppException {
  LocationException(this.locationCode, [String? message])
    : super(message ?? _messageFor(locationCode), locationCode.name);

  final LocationErrorCode locationCode;

  static String _messageFor(LocationErrorCode code) {
    switch (code) {
      case LocationErrorCode.serviceDisabled:
        return 'Dịch vụ định vị đang tắt.';
      case LocationErrorCode.denied:
        return 'Bạn chưa cho phép FOORA dùng vị trí.';
      case LocationErrorCode.deniedForever:
        return 'Quyền vị trí đã bị từ chối vĩnh viễn.';
      case LocationErrorCode.timeout:
        return 'Không lấy được vị trí của bạn. Vui lòng thử lại.';
    }
  }
}

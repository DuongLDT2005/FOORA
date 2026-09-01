import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Đã xảy ra lỗi máy chủ. Vui lòng thử lại sau.',
    super.code,
  ]);

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

class AuthException extends AppException {
  const AuthException([
    super.message = 'Xác thực không thành công.',
    super.code,
  ]);

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
      default:
        return AuthException(
          e.message ?? 'Đăng nhập/xác thực thất bại.',
          e.code,
        );
    }
  }
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại Wifi/4G.',
    super.code,
  ]);
}

class CacheException extends AppException {
  const CacheException([
    super.message = 'Lỗi truy xuất bộ nhớ tạm.',
    super.code,
  ]);
}

class NotFoundException extends AppException {
  const NotFoundException([
    super.message = 'Không tìm thấy tài nguyên yêu cầu.',
    super.code,
  ]);
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'Bạn không có quyền thực hiện thao tác này.',
    super.code,
  ]);
}

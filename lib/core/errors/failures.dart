import 'exceptions.dart';

/// Base class for errors exposed to the presentation layer.
/// Each failure carries a human-readable [message] that can be shown in a toast.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;

  /// Converts a data-layer [AppException] into the matching [Failure] subtype.
  factory Failure.fromException(AppException exception) {
    if (exception is AuthException) {
      return AuthFailure(exception.message, exception.code);
    } else if (exception is ServerException) {
      return ServerFailure(exception.message, exception.code);
    } else if (exception is NetworkException) {
      return NetworkFailure(exception.message, exception.code);
    } else if (exception is CacheException) {
      return CacheFailure(exception.message, exception.code);
    } else if (exception is NotFoundException) {
      return NotFoundFailure(exception.message, exception.code);
    } else if (exception is PermissionDeniedException) {
      return PermissionDeniedFailure(exception.message, exception.code);
    } else if (exception is LocationException) {
      return LocationFailure(exception.locationCode, exception.message);
    }
    return ServerFailure(exception.message, exception.code);
  }
}

/// Generic server-side error (Firestore, Cloud Functions, Storage).
class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Đã xảy ra lỗi máy chủ. Vui lòng thử lại.',
    super.code,
  ]);
}

/// Authentication error (invalid credentials, disabled account, ...).
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Xác thực thất bại.', super.code]);
}

/// No internet connection or request timeout.
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
    super.code,
  ]);
}

/// Local cache / SharedPreferences error.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Lỗi truy xuất bộ nhớ tạm.', super.code]);
}

/// Requested data does not exist.
class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
    super.code,
  ]);
}

/// User lacks permission for the requested action (blocked by security rules).
class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure([
    super.message = 'Bạn không có quyền thực hiện thao tác này.',
    super.code,
  ]);
}

class LocationFailure extends Failure {
  const LocationFailure(this.locationCode, [String? message])
    : super(message ?? 'Không thể lấy vị trí.', locationCode.name);

  final LocationErrorCode locationCode;
}

/// The account plan's quota was exceeded (e.g. free-plan inventory item limit).
class ResourceExhaustedFailure extends Failure {
  const ResourceExhaustedFailure([
    super.message = 'Đã đạt giới hạn tài nguyên của gói tài khoản.',
    super.code,
  ]);
}

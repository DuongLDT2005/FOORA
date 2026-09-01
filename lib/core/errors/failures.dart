import 'exceptions.dart';

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
    }
    return ServerFailure(exception.message, exception.code);
  }
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Đã xảy ra lỗi máy chủ. Vui lòng thử lại.',
    super.code,
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Xác thực thất bại.', super.code]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
    super.code,
  ]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Lỗi truy xuất bộ nhớ tạm.', super.code]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
    super.code,
  ]);
}

class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure([
    super.message = 'Bạn không có quyền thực hiện thao tác này.',
    super.code,
  ]);
}

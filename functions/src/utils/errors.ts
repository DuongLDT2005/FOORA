import {HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

export function throwUnauthenticated(
  message = "Yêu cầu đăng nhập để thực hiện thao tác này."
): never {
  throw new HttpsError("unauthenticated", message);
}

export function throwPermissionDenied(
  message = "Bạn không có quyền thực hiện thao tác này."
): never {
  throw new HttpsError("permission-denied", message);
}

export function throwNotFound(
  message = "Không tìm thấy dữ liệu yêu cầu."
): never {
  throw new HttpsError("not-found", message);
}

export function throwInvalidArgument(
  message = "Dữ liệu đầu vào không hợp lệ."
): never {
  throw new HttpsError("invalid-argument", message);
}

export function throwResourceExhausted(
  message = "Bạn đã vượt quá giới hạn/quota cho phép."
): never {
  throw new HttpsError("resource-exhausted", message);
}

export function handleFunctionError(
  error: unknown,
  functionName: string
): never {
  if (error instanceof HttpsError) {
    throw error;
  }
  logger.error(`[${functionName}] Unhandled internal error:`, error);
  throw new HttpsError(
    "internal",
    "Đã xảy ra lỗi nội bộ máy chủ. Vui lòng thử lại sau."
  );
}

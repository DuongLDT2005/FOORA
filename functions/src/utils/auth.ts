import {CallableRequest} from "firebase-functions/v2/https";
import {db} from "../config/firebase";
import {Collections} from "../constants/collections";
import {AuthenticatedUser} from "../types";
import {throwPermissionDenied, throwUnauthenticated} from "./errors";

/**
 * Validates request.auth and retrieves the user profile from Firestore.
 */
export async function getAuthenticatedUser(
  request: CallableRequest
): Promise<AuthenticatedUser> {
  if (!request.auth || !request.auth.uid) {
    throwUnauthenticated();
  }

  const uid = request.auth.uid;
  const userDoc = await db.collection(Collections.USERS).doc(uid).get();

  if (!userDoc.exists) {
    throwPermissionDenied("Hồ sơ người dùng không tồn tại.");
  }

  const data = userDoc.data();
  const isActive = data?.isActive ?? true;

  if (!isActive) {
    throwPermissionDenied("Tài khoản của bạn đã bị vô hiệu hóa.");
  }

  let membershipId = data?.membershipId || "free";
  if (membershipId !== "free") {
    const activeSubscriptions = await userDoc.ref
      .collection(Collections.SUBSCRIPTIONS)
      .where("status", "==", "active")
      .limit(10)
      .get();
    const active = activeSubscriptions.docs.find((subscription) => {
      const endDate = subscription.data().endDate;
      return endDate?.toMillis?.() > Date.now();
    });
    membershipId = active?.data().membershipId || "free";
  }

  return {
    uid,
    email: data?.email || request.auth.token.email || "",
    role: data?.role || "member",
    activeHouseholdId: data?.activeHouseholdId,
    membershipId,
    isActive,
  };
}

/**
 * Validates that the caller is an authenticated administrator.
 */
export async function verifyAdmin(
  request: CallableRequest
): Promise<AuthenticatedUser> {
  const user = await getAuthenticatedUser(request);
  if (user.role !== "admin") {
    throwPermissionDenied("Yêu cầu quyền Quản trị viên (Admin).");
  }
  return user;
}

/**
 * Validates that the caller has membership access to the specified household.
 */
export async function verifyHouseholdAccess(
  uid: string,
  householdId: string
): Promise<void> {
  const householdDoc = await db
    .collection(Collections.HOUSEHOLDS)
    .doc(householdId)
    .get();

  if (!householdDoc.exists) {
    throwPermissionDenied("Không tìm thấy thông tin gia đình (Household).");
  }

  const data = householdDoc.data();
  const members: string[] = data?.members || [];
  const ownerId: string = data?.ownerId || "";

  if (ownerId !== uid && !members.includes(uid)) {
    throwPermissionDenied("Bạn không có quyền truy cập vào Household này.");
  }
}

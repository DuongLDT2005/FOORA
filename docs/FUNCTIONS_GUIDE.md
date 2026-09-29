# FOORA – Hướng Dẫn Chi Tiết & Quy Chuẩn Backend Cloud Functions

Tài liệu này cung cấp bản thiết kế cấu trúc chi tiết của **từng function module**, **quy tắc phân tầng mã nguồn (Layer Coding Rules)** và danh sách toàn bộ các Cloud Functions cho dự án **FOORA**.

---

## 1. Quy Chuẩn Phân Tầng Mã Nguồn (Layer Coding Rules)

Để tránh tình trạng "Spaghetti Code" (viết hàng trăm dòng logic, query Firestore, gọi API bên thứ ba dồn hết vào 1 hàm handler), mã nguồn Backend của mỗi module trong `functions/src/` được chia thành **3 tầng rõ ràng**:

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. ENTRYPOINT LAYER (Callables / Triggers / Schedulers)     │
│    - Nhận Request, trích xuất parameters                    │
│    - Xác thực quyền: getAuthenticatedUser() / verifyAdmin() │
│    - Validate schema đầu vào (throwInvalidArgument)         │
│    - Bọc try/catch và gọi Service tương ứng                 │
│    - Định dạng và trả về ApiResponse<T>                     │
└──────────────────────────────┬──────────────────────────────┘
                               │ (chuyển giao dữ liệu sạch)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. SERVICE LAYER (Business Logic thuần túy)                 │
│    - Thực thi toàn bộ quy tắc nghiệp vụ (Business Rules)    │
│    - Tính toán FEFO, kiểm tra quota tháng, gọi Gemini API   │
│    - Xác thực IAP Token (Google Play / App Store)           │
│    - Thực hiện Firestore Transactions / Batch Operations    │
│    - Độc lập, dễ dàng viết Unit Test cho logic              │
└──────────────────────────────┬──────────────────────────────┘
                               │ (gọi hạ tầng)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. INFRASTRUCTURE & SHARED LAYER                            │
│    - config/firebase.ts (Admin SDK instances: db, auth,...) │
│    - constants/collections.ts (Khớp 100% DATABASE.md)       │
│    - utils/ (errors.ts [return never], auth.ts)             │
│    - types/index.ts (Type an toàn)                          │
└─────────────────────────────────────────────────────────────┘
```

### 4 Nguyên Tắc Bất Di Bất Dịch:
1. **Entrypoint phải "mỏng" (Thin Handlers)**: Hàm `onCall`, `onDocumentCreated`, `onSchedule` chỉ đóng vai trò điều hướng và xác thực. Không viết quá 30 dòng code trong 1 entrypoint.
2. **Nghiệp vụ nằm ở Service (Fat Services)**: Mọi xử lý Firestore, AI, IAP validation đều phải được đóng gói thành các class hoặc hàm service riêng biệt trong thư mục `services/`.
3. **Bắt buộc `handleFunctionError` trả về `never`**: Mọi helper ném lỗi và hàm bắt lỗi nội bộ đều phải trả về `never` để TypeScript hiểu luồng thực thi chấm dứt ngay tại đó.
4. **Không bao giờ hardcode**: Mọi tên collection, status, role đều phải import từ `constants/collections.ts` và `types/index.ts`.

---

## 2. Cấu Trúc Chi Tiết Của Từng Module (`functions/src/`)

```text
functions/src/
├── config/
│   └── firebase.ts                 # Singleton Admin SDK, export db, auth, storage, messaging
├── constants/
│   └── collections.ts              # Hằng số Collections & Subcollections khớp 100% DATABASE.md
├── types/
│   └── index.ts                    # TypeScript types (AuthenticatedUser, ApiResponse, v.v.)
├── utils/
│   ├── auth.ts                     # getAuthenticatedUser, verifyAdmin, verifyHouseholdAccess
│   └── errors.ts                   # throwUnauthenticated, throwPermissionDenied, handleFunctionError (return never)
│
├── auth/                           # 1. AUTH MODULE
│   ├── triggers/
│   │   └── on_user_created.ts      # Trigger tạo document users/{userId} khi có Auth user mới
│   ├── services/
│   │   └── auth_service.ts         # Logic khởi tạo dữ liệu mặc định cho user & household
│   └── index.ts
│
├── inventory/                      # 2. INVENTORY MODULE
│   ├── schedulers/
│   │   └── check_expiry_cron.ts    # Cron quét hạn sử dụng hàng ngày lúc 07:00 sáng
│   ├── services/
│   │   └── expiry_service.ts       # Logic quét FEFO, tính số ngày còn lại & tạo notifications
│   └── index.ts
│
├── receipt/                        # 3. RECEIPT MODULE
│   ├── callables/
│   │   └── parse_receipt_ai.ts     # Callable API nhận OCR text -> trả về danh sách món ăn
│   ├── services/
│   │   └── receipt_parser.ts       # Logic prompt Gemini 1.5 Flash bóc tách món, số lượng, đơn vị
│   └── index.ts
│
├── ai/                             # 4. AI ASSISTANT MODULE
│   ├── callables/
│   │   ├── chat_with_assistant.ts  # Callable trò chuyện AI gợi ý món ăn, tra cứu dinh dưỡng
│   │   └── get_ai_quota.ts         # Callable kiểm tra số lượt quét/chat còn lại trong tháng
│   ├── services/
│   │   ├── ai_chat_service.ts      # Logic tương tác Gemini API & quản lý context
│   │   └── quota_service.ts        # Logic kiểm tra & trừ quota trong users/{userId}/ai_usage/current
│   └── index.ts
│
├── notification/                   # 5. NOTIFICATION MODULE
│   ├── triggers/
│   │   └── on_notification_new.ts  # Trigger lắng nghe users/{userId}/notifications -> gửi FCM
│   ├── services/
│   │   └── fcm_service.ts          # Logic lấy device token và gửi tin nhắn đẩy FCM đa nền tảng
│   └── index.ts
│
├── membership/                     # 6. MEMBERSHIP MODULE
│   ├── schedulers/
│   │   └── reset_monthly_quota.ts  # Cron chạy ngày 1 hàng tháng: reset lượt dùng AI về 0
│   ├── callables/
│   │   └── get_membership_info.ts  # Callable lấy thông tin gói thành viên hiện tại
│   ├── services/
│   │   └── membership_service.ts   # Logic kiểm tra gói, áp dụng giới hạn items & scan
│   └── index.ts
│
├── payment/                        # 7. PAYMENT (CAS QR PAY)
│   ├── callables/
│   │   ├── create_cas_payment_order.ts
│   │   └── cancel_cas_payment_order.ts
│   ├── webhooks/
│   │   └── cas_transactions_webhook.ts
│   ├── schedules/
│   │   └── expire_pending_payments.ts
│   ├── services/
│   │   ├── cas_client.ts
│   │   ├── cas_webhook.ts
│   │   └── payment_service.ts
│   ├── types/
│   │   └── payment_types.ts
│   ├── config.ts
│   └── index.ts
│
├── household/                      # 8. HOUSEHOLD MODULE
│   ├── callables/
│   │   ├── create_household.ts     # [IN SCOPE] Callable tạo Household mới và set activeHouseholdId
│   │   └── join_household.ts       # [HẠ TẦNG CHO SAU] Tham gia qua mã mời
│   ├── services/
│   │   └── household_service.ts    # Logic quản lý thành viên, đảm bảo tính toàn vẹn dữ liệu
│   └── index.ts
│
├── admin/                          # 9. ADMIN MODULE
│   ├── callables/
│   │   ├── set_user_role.ts        # Callable gán quyền Admin / Member (Custom Claims & Firestore)
│   │   ├── toggle_user_active.ts   # Callable khóa/mở tài khoản + revokeRefreshTokens tức thì
│   │   └── get_system_metrics.ts   # Callable thống kê toàn hệ thống (Users, Doanh thu, AI calls)
│   ├── services/
│   │   └── admin_service.ts        # Logic tương tác Admin SDK Auth & tổng hợp số liệu
│   └── index.ts
│
└── index.ts                        # Cổng export tập trung 9 namespace ra ngoài Firebase
```

---

## 3. Bảng Chi Tiết Toàn Bộ Functions Của Dự Án

| Module | Tên Function | Loại Trigger | Path / Schedule | Đầu Vào (Input) | Đầu Ra (Output) / Hành Động |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **`auth`** | `onUserCreated` | Auth Trigger | `firebaseAuth.user().onCreate` | `UserRecord` (uid, email, displayName) | Khởi tạo `users/{uid}` (gán `role: 'member'`, `membershipId: 'free'`, `isActive: true` bằng `merge: true`, client cập nhật `fullName`), tự động tạo `households` mặc định ("Tủ lạnh của {name}") với `activeItemCount: 0` và khởi tạo `ai_usage/current`. |
| **`inventory`** | `addInventoryItem` | Callable | `onCall` | `{ householdId, name, categoryId, quantity, unit, storageLocationId, ... }` | Chạy Firestore Transaction kiểm tra `foodLimit` của Membership (`Free: 30`, `Premium: null`), tính hạn dùng và tăng `activeItemCount` lên 1. |
| | `onInventoryItemMutation` | Firestore | `households/{householdId}/inventory_items/{itemId}` | Snapshot document update/delete | Lắng nghe `onUpdate` & `onDelete` (không bắt `onCreate` để tránh double count) đồng bộ `activeItemCount` khi đổi trạng thái sang `consumed`/`discarded`. |
| | `checkExpiryDailyCron` | Scheduled | `0 7 * * *` (07:00 VN) | Không có (Tự động) | Quét các item sắp hết hạn (<= 3 ngày) / hết hạn (< 0 ngày) -> ghi `notifications`. |
| **`receipt`** | `parseReceiptAi` | Callable | `onCall` | `{ ocrText: string; householdId: string }` | Trích xuất JSON danh sách thực phẩm (`name`, `quantity`, `unit`, `storageLocationId`). |
| **`ai`** | `chatWithAssistant` | Callable | `onCall` | `{ prompt: string; householdId?: string }` | Trả về câu trả lời AI Markdown + cập nhật `receiptScanUsed` nếu cần. |
| | `getAiQuota` | Callable | `onCall` | Không có | `{ period: '2026-09', used: 3, limit: 5, isUnlimited: false }`. |
| **`notification`** | `onNotificationCreated` | Firestore | `users/{userId}/notifications/{id}` | Snapshot document thông báo mới | Gửi tin nhắn FCM đến toàn bộ thiết bị đang active trong `users/{userId}/devices`. |
| **`membership`** | `resetMonthlyQuotaCron` | Scheduled | `0 0 1 * *` (00:00 ngày 1) | Không có (Tự động) | Batch update reset `ai_usage/current.receiptScanUsed = 0` cho toàn bộ user Free. |
| | `getMembershipInfo` | Callable | `onCall` | Không có | Thông tin chi tiết gói và hạn mức sử dụng. |
| **`payment`** | `createCasPaymentOrder` | Callable | `onCall` | `{ membershipId: string }` | Creates or reuses a server-priced Cas QR order. |
| | `cancelCasPaymentOrder` | Callable | `onCall` | `{ paymentId: string }` | Cancels a pending payment. |
| | `casTransactionsWebhook` | HTTP | `onRequest` | Signed Cas transaction | Reconciles and atomically activates Premium. |
| | `expirePendingPayments` | Scheduled | Every 5 minutes | None | Expires overdue pending orders. |
| **`household`** | `createHousehold` | Callable | `onCall` **[Scope Đợt Này]** | `{ name: string }` | Tạo document `households/{id}`, thêm user vào `members`, set `user.activeHouseholdId`. |
| | `joinHousehold` | Callable | `onCall` **[Hạ Tầng Cho Sau]** | `{ householdId: string }` | Thêm user vào `households.members`, cập nhật `user.activeHouseholdId`. |
| **`admin`** | `setUserRole` | Callable | `onCall` (Admin only) | `{ targetUid: string; role: 'admin' \| 'member' }` | Set Firebase Auth Custom Claims (`{admin: true}`) & cập nhật `users/{targetUid}.role`. |
| | `toggleUserActive` | Callable | `onCall` (Admin only) | `{ targetUid: string; isActive: boolean }` | Gọi `auth.revokeRefreshTokens(targetUid)` + `auth.updateUser(targetUid, {disabled: !isActive})` + cập nhật `users/{targetUid}.isActive`. |
| | `getSystemMetrics` | Callable | `onCall` (Admin only) | Không có | Tổng hợp: tổng số users, số gói premium active, số lượt quét AI trong tháng. |

---

## 4. Chi Tiet Thuc Thi: Cas QR Pay & Khoa Tai Khoan Tuc Thi

### A. Cas QR Pay

Payment exports:

- `createCasPaymentOrder`: authenticated callable; resolves price and duration
  from `memberships/{membershipId}`, creates/reuses a pending order, then calls Cas.
- `cancelCasPaymentOrder`: authenticated callable; only transitions `pending`
  payments to `cancelled`.
- `casTransactionsWebhook`: HTTP endpoint; verifies `X-Casso-Signature` with
  HMAC SHA-512, reconciles amount/reference/time, and atomically activates Premium.
- `expirePendingPayments`: scheduled function that expires overdue pending orders.

Required secrets are `CAS_CLIENT_ID`, `CAS_SECRET_KEY`, `CAS_ACCESS_TOKEN`,
and `CAS_WEBHOOK_SECRET`. Non-secret parameters are `CAS_BASE_URL`,
`CAS_QR_PAY_PATH`, and `PAYMENT_EXPIRY_MINUTES`.

Handlers remain thin. Provider parsing lives in `services/cas_webhook.ts`; order,
idempotency, and entitlement transactions live in `services/payment_service.ts`.

---

### B. Khóa Tài Khoản Tức Thì Với `revokeRefreshTokens` (`functions/src/admin/callables/toggle_user_active.ts`)
```typescript
import {onCall} from "firebase-functions/v2/https";
import {auth, db, REGION} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {ApiResponse} from "../../types";
import {verifyAdmin} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";

interface ToggleActivePayload {
  targetUid: string;
  isActive: boolean;
}

export const toggleUserActive = onCall<ToggleActivePayload>(
  {region: REGION},
  async (request): Promise<ApiResponse<void>> => {
    try {
      // 1. Chỉ Quản trị viên (Admin) mới có quyền gọi
      await verifyAdmin(request);

      const {targetUid, isActive} = request.data;
      if (!targetUid) {
        throwInvalidArgument("ID người dùng mục tiêu không được để trống.");
      }

      // 2. Cập nhật trạng thái trong Firebase Auth & Hủy token phiên tức thì nếu bị khóa
      await auth.updateUser(targetUid, {disabled: !isActive});
      if (!isActive) {
        // Thu hồi toàn bộ refresh token để kick người dùng ra ngay lập tức
        await auth.revokeRefreshTokens(targetUid);
      }

      // 3. Cập nhật Firestore document
      await db.collection(Collections.USERS).doc(targetUid).update({
        isActive,
        updatedAt: new Date(),
      });

      return {
        success: true,
        message: isActive ? "Đã mở khóa tài khoản." : "Đã khóa tài khoản và hủy phiên làm việc.",
      };
    } catch (error) {
      handleFunctionError(error, "toggleUserActive");
    }
  }
);
```

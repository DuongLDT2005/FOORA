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
5. **Quyền gói lấy từ subscription**: Mọi kiểm tra gói/hạn mức (`foodLimit`, `receiptScanQuota`, `aiAssistantDailyQuota`) dùng `MembershipService.resolveMembershipId` + `MembershipService.getLimits`; không đọc `users.membershipId` (chỉ là cache) và không có giá trị fallback cứng — thiếu cấu hình `memberships` sẽ trả lỗi `failed-precondition`.

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
│   ├── services/
│   │   ├── expiry_planner.ts       # Pure: ngày còn lại theo giờ VN, lọc theo expiryAlertDays từng user
│   │   └── expiry_service.ts       # runForHour: user có reminderHour == giờ hiện tại -> tạo notifications
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
│   │   └── ai_assistant.ts         # Callable chat AI chỉ đọc kho, text hoặc voice transcript
│   ├── services/
│   │   └── ai_assistant_service.ts # Context kho, model AI (Gemini), quota ngày và idempotency
│   ├── schedulers/
│   │   └── cleanup_ai_requests.ts  # Hoàn quota request treo hết lease
│   └── index.ts
│
├── notification/                   # 5. NOTIFICATION MODULE
│   ├── triggers/
│   │   └── on_notification_new.ts  # Trigger lắng nghe users/{userId}/notifications -> gửi FCM
│   ├── schedulers/
│   │   └── hourly_reminder_cron.ts # Job nhắc duy nhất: nhắc hạn dùng + nhắc đi chợ theo reminderHour
│   ├── services/
│   │   ├── fcm_service.ts          # Logic lấy device token và gửi tin nhắn đẩy FCM đa nền tảng
│   │   ├── notification_settings.ts # Pure: parse users.notificationSettings, vnClock (giờ/tuần ISO VN)
│   │   ├── reminder_planner.ts     # Pure: nội dung nhắc đi chợ
│   │   └── shopping_reminder_service.ts # Query user đúng thứ + giờ, ghi notification shopping_{YYYY}W{ww}
│   └── index.ts
│
├── membership/                     # 6. MEMBERSHIP MODULE
│   ├── schedulers/
│   │   └── reset_monthly_quota.ts  # Cron chạy ngày 1 hàng tháng: reset lượt dùng AI về 0
│   ├── callables/
│   │   └── get_membership_info.ts  # Callable lấy thông tin gói thành viên hiện tại
│   ├── services/
│   │   ├── entitlement.ts          # Rule thuần: subscription active -> gói hiệu lực (unit-test được)
│   │   └── membership_service.ts   # Entitlement resolver dùng chung, đọc giới hạn từ memberships, đồng bộ cache users.membershipId
│   └── index.ts
│
├── payment/                        # 7. PAYMENT (payOS QR; export names keep the legacy `Cas` prefix)
│   ├── callables/
│   │   ├── create_cas_payment_order.ts
│   │   └── cancel_cas_payment_order.ts
│   ├── webhooks/
│   │   └── cas_transactions_webhook.ts
│   ├── schedules/
│   │   └── expire_pending_payments.ts
│   ├── services/
│   │   ├── payos_client.ts
│   │   ├── payos_webhook.ts
│   │   └── payment_service.ts
│   ├── types/
│   │   └── payment_types.ts
│   ├── config.ts
│   └── index.ts
│
├── household/                      # 8. HOUSEHOLD MODULE
│   ├── callables/                  # 10 callable mỏng: generate/revoke/getActive invitation,
│   │                               # getInvitationInfo, join, leave, removeMember, switch,
│   │                               # updateHouseholdName, getHouseholdMembers
│   ├── services/
│   │   ├── household_service.ts    # Transaction thành viên + mã mời, chống dò mã, notification
│   │   └── invite_code.ts          # Pure: sinh / chuẩn hóa / validate mã 6 ký tự
│   └── index.ts
│
├── shopping/                       # 9. SHOPPING MODULE (PLAN_01)
│   ├── callables/
│   │   ├── delete_shopping_list.ts         # Xóa danh sách + toàn bộ món (recursive delete)
│   │   ├── import_shopping_items.ts        # importShoppingItemsToInventory: món đã mua -> kho
│   │   └── get_shopping_suggestions.ts     # Gợi ý "Hay mua"
│   ├── services/
│   │   ├── purchase_frequency.ts   # Pure: thuật toán "Hay mua" (median khoảng cách, tồn kho)
│   │   ├── shopping_validation.ts  # Pure: validate payload nhập kho
│   │   └── shopping_service.ts     # Transaction nhập kho, đọc lịch sử mua & món đang chờ
│   └── index.ts
│
├── admin/                          # 10. ADMIN MODULE
│   ├── callables/
│   │   ├── set_user_role.ts        # Callable gán quyền Admin / Member (Custom Claims & Firestore)
│   │   ├── toggle_user_active.ts   # Callable khóa/mở tài khoản + revokeRefreshTokens tức thì
│   │   └── get_system_metrics.ts   # Callable thống kê toàn hệ thống (Users, Doanh thu, AI calls)
│   ├── services/
│   │   └── admin_service.ts        # Logic tương tác Admin SDK Auth & tổng hợp số liệu
│   └── index.ts
│
└── index.ts                        # Cổng export tập trung các module ra ngoài Firebase
```

---

## 3. Bảng Chi Tiết Toàn Bộ Functions Của Dự Án

| Module | Tên Function | Loại Trigger | Path / Schedule | Đầu Vào (Input) | Đầu Ra (Output) / Hành Động |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **`auth`** | `onUserCreated` | Auth Trigger | `firebaseAuth.user().onCreate` | `UserRecord` (uid, email, displayName) | Khởi tạo `users/{uid}` (gán `role: 'member'`, `membershipId: 'free'`, `isActive: true` bằng `merge: true`, client cập nhật `fullName`), tự động tạo `households` mặc định ("Tủ lạnh của {name}") với `activeItemCount: 0` và khởi tạo `ai_usage/current`. |
| **`inventory`** | `addInventoryItem` | Callable | `onCall` | `{ householdId, name, categoryId, quantity, unit, storageLocationId, ... }` | Chạy Firestore Transaction kiểm tra `foodLimit` đọc từ `memberships/{membershipId}` (seed: `Free: 30`, `Premium: null`), tính hạn dùng và tăng `activeItemCount` lên 1. Đây là đường duy nhất để client tạo `inventory_items` (Rules chặn create trực tiếp). |
| | `batchAddInventoryItems` | Callable | `onCall` | `{ householdId, items[], receiptId? }` | Thêm nhiều món từ hóa đơn trong một transaction, kiểm tra `foodLimit` và tăng `activeItemCount`. |
| | `onInventoryItemMutation` | Firestore | `households/{householdId}/inventory_items/{itemId}` | Snapshot document update/delete | Lắng nghe `onUpdate` & `onDelete` (không bắt `onCreate` để tránh double count) đồng bộ `activeItemCount` khi đổi trạng thái sang `consumed`/`discarded`. |
| **`receipt`** | `parseReceiptAi` | Callable | `onCall` | `{ ocrText: string; householdId: string }` | Trích xuất JSON danh sách thực phẩm (`name`, `quantity`, `unit`, `storageLocationId`). |
| **`ai`** | `aiAssistant` | Callable | `onCall` | `{ requestId, sessionId, householdId, message, inputMode }` | `sessionId` là UUID v4 do client tạo cho mỗi cuộc trò chuyện; lịch sử gửi model chỉ lấy trong session đó. Trả JSON gồm `reply`, recipe đã validate và action **đề xuất** (`add_inventory` được khớp với `foods` như quét hóa đơn; `consume`/`discard` giữ nguyên đơn vị người dùng nói, áp dụng FEFO khi xác nhận); xác thực household, quota AI theo ngày Việt Nam và request idempotency; không ghi kho. |
| | `applyAiActions` | Callable | `onCall` | `{ messageId, decisions[] }` | Duyệt/loại toàn bộ action của một message, kiểm tra lại batch và quyền trong transaction, FEFO, foodLimit, lưu kết quả từng action; retry cùng decisions không ghi lần hai. |
| | `cleanupExpiredAiRequests` | Scheduled | Mỗi 5 phút | Request AI hết lease | Chuyển pending request treo sang failed và hoàn quota đúng ngày đã giữ. |
| **`notification`** | `onNotificationCreated` | Firestore | `users/{userId}/notifications/{id}` | Snapshot document thông báo mới | Gửi tin nhắn FCM đến toàn bộ thiết bị đang active trong `users/{userId}/devices`. |
| | `hourlyReminderCron` | Scheduled | `0 * * * *` (giờ VN) | Không có (Tự động) | Với user có `notificationSettings.reminderHour` = giờ hiện tại: ghi `expiration_alert` (ngày đầu sau hạn) và `upcoming_expiration` (đúng 1/3/7 ngày đã chọn). Với user đúng thứ + giờ nhắc đi chợ: ghi `shopping_reminder` (id `shopping_{YYYY}W{ww}`, `create()` nên chạy lại không gửi trùng; bỏ qua nếu danh sách và gợi ý đều rỗng hoặc `pushEnabled = false`). Thay cho `checkExpiryDailyCron` đã xóa → tổng **2** Scheduler job (`hourlyReminderCron`, `expirePendingPayments`). |
| **`shopping`** | `deleteShoppingList` | Callable | `onCall` (Member) | `{ householdId, shoppingListId }` | Xóa danh sách và toàn bộ `items` (client không được xóa list trực tiếp). |
| | `importShoppingItemsToInventory` | Callable | `onCall` (Member) | `{ householdId, shoppingListId, items: [{ shoppingItemId, storageLocationId, categoryId, actualQuantity, purchaseDate? }] }` (1..50) | Một transaction: đọc lại món (phải đã tick, chưa nhập), tạo batch qua `InventoryService.executeBatchAddInTransaction` (foodLimit, `activeItemCount`, hạn dùng theo shelf-life rule), đánh dấu món đã nhập. Vượt `foodLimit` → `resource-exhausted`; người khác đã nhập → `failed-precondition`; gọi lại sau khi thành công trả id cũ. `categoryId` phải tồn tại và khác `other`. |
| | `getShoppingSuggestions` | Callable | `onCall` (Member) | `{ householdId }` | Gợi ý "Hay mua" từ lịch sử `inventory_items` 180 ngày (≥ 3 ngày mua, median khoảng cách, đang hết/sắp hết, chưa có trong danh sách), tối đa 10, kèm `reason`. Không ghi dữ liệu, không tốn quota AI. |
| **`membership`** | `resetMonthlyQuotaCron` | Scheduled | `0 0 1 * *` (00:00 ngày 1) | Không có (Tự động) | Batch update reset `ai_usage/current.receiptScanUsed = 0` cho toàn bộ user Free. |
| | `getMembershipInfo` | Callable | `onCall` | Không có | Thông tin chi tiết gói và hạn mức sử dụng. |
| **`payment`** | `createCasPaymentOrder` | Callable | `onCall` | `{ membershipId: string }` | Creates or reuses a server-priced payOS QR order. |
| | `cancelCasPaymentOrder` | Callable | `onCall` | `{ paymentId: string }` | Cancels a pending payment. |
| | `casTransactionsWebhook` | HTTP | `onRequest` | Signed payOS webhook | Verifies the payOS checksum, reconciles and atomically activates Premium. |
| | `expirePendingPayments` | Scheduled | Every 5 minutes | None | Expires overdue pending orders. |
| **`household`** | `generateHouseholdInvitation` | Callable | `onCall` (Owner) | `{ householdId }` | Tạo mã 6 ký tự (hạn cố định 7 ngày), thu hồi mã đang hiệu lực cũ. Trả `{ invitationId, code, householdId, householdName, expiresAt }`. |
| | `getActiveHouseholdInvitation` | Callable | `onCall` (Owner) | `{ householdId }` | Mã đang hiệu lực hoặc `null` (tự đánh dấu `expired` khi quá hạn). |
| | `revokeHouseholdInvitation` | Callable | `onCall` (Owner) | `{ householdId, invitationId }` | Thu hồi mã; kiểm tra mã thuộc đúng household. |
| | `getHouseholdInvitationInfo` | Callable | `onCall` | `{ code }` | Xem trước tên nhà, chủ nhà, `memberCount`/`memberLimit`. Tính vào giới hạn nhập sai. |
| | `joinHousehold` | Callable | `onCall` | `{ code }` | Transaction: kiểm tra mã, giới hạn thành viên theo `memberLimit` gói của owner (trần 20; đầy → `failed-precondition` + notification gợi ý nâng cấp cho owner), `arrayUnion`, set `activeHouseholdId`, `useCount + 1`, notification `system` cho owner. Đã là thành viên → chỉ chuyển sang nhà đó. Sai quá 10 lần/giờ → `resource-exhausted`. |
| | `leaveHousehold` | Callable | `onCall` (Member) | `{ householdId }` | Owner không được rời. Member bị `arrayRemove`, `activeHouseholdId` về household user sở hữu (tạo mới nếu chưa có). |
| | `removeHouseholdMember` | Callable | `onCall` (Owner) | `{ householdId, memberUserId }` | Như leave cho member đó + notification `system` cho người bị xóa. |
| | `switchHousehold` | Callable | `onCall` (Member) | `{ householdId }` | Đổi `activeHouseholdId` sang household user đang là thành viên. |
| | `updateHouseholdName` | Callable | `onCall` (Owner) | `{ householdId, name }` | Đổi tên 1..100 ký tự. |
| | `getHouseholdMembers` | Callable | `onCall` (Member) | `{ householdId }` | `[{ id, fullName, avatarUrl, role, isCurrentUser }]` – không trả email. |
| **`admin`** | `setUserRole` | Callable | `onCall` (Admin only) | `{ targetUid: string; role: 'admin' \| 'member' }` | Set Firebase Auth Custom Claims (`{admin: true}`) & cập nhật `users/{targetUid}.role`. |
| | `toggleUserActive` | Callable | `onCall` (Admin only) | `{ targetUid: string; isActive: boolean }` | Gọi `auth.revokeRefreshTokens(targetUid)` + `auth.updateUser(targetUid, {disabled: !isActive})` + cập nhật `users/{targetUid}.isActive`. |
| | `getSystemMetrics` | Callable | `onCall` (Admin only) | Không có | Tổng hợp: tổng số users, số gói premium active, số lượt quét AI trong tháng. |

---

## 4. Chi Tiet Thuc Thi: payOS QR & Khoa Tai Khoan Tuc Thi

### Kiểm tra AI Voice trên máy phát triển

1. Chạy `cd functions`, `npm run lint`, `npm test`; ở root chạy `flutter analyze` và `flutter test`.
2. Tại root, chạy `npm exec --yes --package firebase-tools -- firebase emulators:exec --config firebase.ai-test.json --only firestore --project foora-app "node functions/test/ai_emulator.integration.js"`. Bài kiểm tra này dùng project/cổng Emulator riêng, tạo dữ liệu mẫu và kiểm tra apply đồng thời, FEFO, stale snapshot, foodLimit, cùng dry run/apply backfill. Nó dùng Admin SDK nên không thay thế bài kiểm tra quyền client theo Firestore Rules.
3. Muốn xem báo cáo backfill trên dữ liệu Emulator đã nạp: trong `functions`, chạy `npm run backfill:initial-quantity`; chỉ chạy `npm run backfill:initial-quantity -- --apply` sau khi kiểm tra báo cáo. Đặt `FIRESTORE_EMULATOR_HOST` đúng cổng Emulator đang chạy. Script chỉ hỗ trợ Emulator, không ghi production.

Trước khi phát hành: cấu hình `OPENROUTER_API_KEY` trong Firebase Secret Manager (dùng chung với quét hóa đơn), thử model được chọn bằng tài khoản thật để kiểm tra timeout/chi phí, kiểm tra micro và quyền tiếng Việt trên thiết bị thật, triển khai index/Rules cùng Functions, chạy migration dữ liệu thật bằng quy trình riêng và chỉ bật App Check enforcement sau khi client đã tích hợp, kiểm tra đủ nền tảng.

### A. payOS QR

The provider is **payOS**; the export names keep the historical `Cas` prefix
for routing compatibility (see `docs/PAYMENT_TEST_GUIDE.md`).

Payment exports:

- `createCasPaymentOrder`: authenticated callable; resolves price and duration
  from `memberships/{membershipId}`, creates/reuses a pending order, then calls payOS.
- `cancelCasPaymentOrder`: authenticated callable; only transitions `pending`
  payments to `cancelled`.
- `casTransactionsWebhook`: HTTP endpoint; verifies the payOS signature with
  `PAYOS_CHECKSUM_KEY`, reconciles amount/reference/time, and atomically activates Premium.
- `expirePendingPayments`: scheduled function that expires overdue pending orders.

Required secrets are `PAYOS_CLIENT_ID`, `PAYOS_API_KEY` and `PAYOS_CHECKSUM_KEY`.
Non-secret parameters are `PAYOS_BASE_URL`, `PAYOS_RETURN_URL`,
`PAYOS_CANCEL_URL` and `PAYMENT_EXPIRY_MINUTES`.

Handlers remain thin. Provider parsing lives in `services/payos_webhook.ts`; order,
idempotency, and entitlement transactions live in `services/payment_service.ts`.
Subscriptions are created with `autoRenew: false`; there is no auto-renew callable.

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

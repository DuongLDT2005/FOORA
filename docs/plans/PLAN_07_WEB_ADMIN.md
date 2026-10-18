# PLAN 07 – Web admin dashboard (gồm đăng nhập admin)

> Chức năng bổ sung trong `PRM393_Project.docx`: *system metrics, user management (lock/unlock accounts), membership plan
> configuration, shelf-life rule management, payment transactions, AI usage and quota monitoring* + "Admins log in to the web dashboard".
> Hiện có: route + guard `/admin/*` trong `app_router.dart` (đang dùng `_PlaceholderScreen`), `isAdminProvider` (đọc `users.role`),
> 29 file stub `// TODO` trong `lib/features/admin/`, `functions/src/admin/index.ts = export {}`,
> seed tài khoản `foora.team@gmail.com` có `role: "admin"` (chưa có custom claim).

## 1. Công nghệ

| Phần | Công nghệ | Ghi chú |
|---|---|---|
| Ứng dụng web | Flutter Web, **cùng codebase** (đã chốt) | `flutter run -d chrome --dart-define-from-file=.env.json` |
| Quyền admin | Firebase Auth **custom claim** `admin: true` | Nằm trong ID token, client không sửa được; Firestore `role` chỉ để hiển thị |
| Dữ liệu admin | Cloud Functions callable (Admin SDK) | Rules hiện không cho client đọc `users`/`payments` người khác → giữ nguyên, mọi truy vấn chéo user qua callable có `verifyAdmin` |
| Đếm số liệu | Firestore aggregation `count()` (Admin SDK) | Rẻ: tính theo index entries, không đọc từng doc |
| Bảng | `PaginatedDataTable` / `DataTable` (Flutter built-in) | Không thêm package |
| Biểu đồ | `fl_chart ^1.2.0` (dùng chung PLAN 06) | |
| Triển khai | Firebase Hosting (gói free) | Tech Lead deploy; `firebase.json` hiện **không** có `hosting` → thêm lại (mục 7) |

## 2. Quyền admin – custom claim (làm đầu tiên)

1. Script `functions/src/scripts/set_admin_claim.ts`:
   `node lib/scripts/set_admin_claim.js --email foora.team@gmail.com [--revoke] [--prod]`
   → `auth.setCustomUserClaims(uid, {admin: true})` + `users/{uid}.role = "admin"`.
   Thêm bước này vào `seed_firestore.ts` cho tài khoản admin.
2. `verifyAdmin` (`functions/src/utils/auth.ts`): kiểm tra `request.auth.token.admin === true` **trước**, sau đó vẫn yêu cầu `users/{uid}.isActive`.
   Không còn tin `users.role`.
3. Flutter `isAdminProvider` (`core/firebase/auth_session_providers.dart`): dựa trên
   `FirebaseAuth.instance.idTokenChanges()` → `user.getIdTokenResult()` → `claims?['admin'] == true` (đặt trong datasource auth, provider chỉ đọc kết quả).
   Sau khi đăng nhập admin, gọi `getIdTokenResult(true)` 1 lần để lấy claim mới nhất.
4. Rules: **không** mở quyền ghi trực tiếp cho admin trên `memberships`/`shelf_life_rules`/`users` (giữ `allow write: if false`).
   Mọi thao tác ghi của admin đi qua callable để validate + ghi audit log.
5. Admin tự khóa chính mình / tự gỡ quyền chính mình → backend từ chối (`failed-precondition`).

## 3. Backend – module `functions/src/admin/`

```
admin/
├── callables/
│   ├── get_system_metrics.ts
│   ├── list_users.ts
│   ├── set_user_active.ts          # = toggleUserActive trong FUNCTIONS_GUIDE
│   ├── set_user_role.ts
│   ├── list_payments.ts
│   ├── upsert_membership_plan.ts
│   ├── upsert_shelf_life_rule.ts
│   ├── set_shelf_life_rule_active.ts
│   └── get_ai_usage_overview.ts
├── services/
│   ├── admin_metrics_service.ts
│   ├── admin_user_service.ts
│   ├── admin_config_service.ts     # memberships + shelf_life_rules
│   ├── admin_audit.ts              # write admin_audit_logs
│   └── validators.ts               # pure, unit-tested
└── index.ts
```
Mọi callable: `const admin = await verifyAdmin(request)` dòng đầu; `{region: REGION}`; handler < 30 dòng.
Mọi thao tác **ghi** tạo 1 doc `admin_audit_logs/{autoId}`: `{adminUid, action, targetPath, before, after, createdAt}` (server-only, Rules deny).

### 3.1 `getSystemMetrics()` → số liệu dashboard
Dùng `count()`:
- `totalUsers` = `users.count()`; `activeUsers` = `users.where("isActive","==",true).count()`;
- `activePremium` = `collectionGroup("subscriptions").where("status","==","active").where("endDate",">",now).count()`;
- `totalHouseholds`, `activeInventoryItems` = `collectionGroup("inventory_items").where("status","==","active").count()`;
- `paymentsThisMonth` = `collectionGroup("payments").where("status","==","completed").where("paidAt",">=",startOfMonthVn).count()`
  và `revenueThisMonth` = `aggregate({sum: AggregateField.sum("amount")})` cùng điều kiện;
- `receiptScansThisMonth` = `collectionGroup("ai_usage").where("period","==",periodVn)` → `aggregate sum("receiptScanUsed")`;
- `assistantCallsToday` = `collectionGroup("ai_usage").where("assistantDate","==",todayVn)` → `sum("assistantUsed")` (sau PLAN 04);
- `newUsersLast7Days` theo ngày: `users.where("createdAt", ">=", d-6)` → đếm theo ngày VN (≤ vài trăm doc, đọc trực tiếp).
Cache kết quả 5 phút trong `admin_cache/metrics` (server-only) để mở dashboard liên tục không tốn đọc.

### 3.2 `listUsers({pageSize = 20, cursor?, emailPrefix?})`
- Không có search → `users.orderBy("createdAt","desc").startAfter(cursorDoc).limit(pageSize)`.
- Có `emailPrefix` (lowercase) → `where("email", ">=", p).where("email", "<", p + "").orderBy("email").limit(pageSize)`
  (prefix search – ghi rõ trên UI "tìm theo đầu email").
- Trả `{users: [{uid, fullName, email, role, isActive, membershipId, createdAt}], nextCursor}`; `membershipId` là cache, ghi chú "Gói (cache)".
  Gói chính xác: gọi `MembershipService.resolveMembershipId` cho từng user trong trang (≤ 20 query) – **bật**, vì admin cần đúng.

### 3.3 `setUserActive({targetUid, isActive})`
Đúng mẫu đã có trong FUNCTIONS_GUIDE §4.B: `auth.updateUser(disabled: !isActive)`, khóa thì `revokeRefreshTokens`, update `users.isActive`, audit.
Client app (đã có) đăng xuất user khi `isActive == false` trong stream.

### 3.4 `setUserRole({targetUid, role: "admin" | "member"})`
`setCustomUserClaims(targetUid, role === "admin" ? {admin: true} : {})` (giữ claim khác nếu có), update `users.role`, `revokeRefreshTokens` để token cũ hết hiệu lực, audit.

### 3.5 `listPayments({status?, pageSize = 20, cursor?})`
`collectionGroup("payments")` (+ `where status`) `.orderBy("createdAt","desc")`; trả kèm `userId` (`doc.ref.parent.parent.id`) và email người dùng (`getAll` users).
Chỉ xem; xử lý `requires_review` (chấp nhận/hoàn tiền) là **future work** theo PAYMENT_END_TO_END_PLAN – UI hiện nhãn và hướng dẫn đối soát thủ công.

### 3.6 `upsertMembershipPlan({membershipId, name, price, durationDays, foodLimit, receiptScanQuota, aiAssistantDailyQuota, isActive})`
Validator: `membershipId ∈ {"free","premium"}` (không tạo gói mới – app chỉ hỗ trợ 2 gói);
`price` số nguyên ≥ 0 (free phải = 0); `durationDays` null (free) hoặc 1..366; các quota `null` hoặc số nguyên 0..100000; `name` 1..50.
Không cho `isActive=false` với `free`. Ghi `updatedAt`, audit before/after.
Ảnh hưởng ngay: app đọc `memberships` khi mở; backend đọc mỗi request (MembershipService).

### 3.7 Shelf-life rules
- Đọc: Rules đã cho authenticated đọc `shelf_life_rules`, `foods`, `food_categories` → admin đọc trực tiếp (Firestore query trong datasource admin), lọc theo `foodId`.
- `upsertShelfLifeRule({ruleId?, foodId, storageLocationId, minValue, maxValue, unit, isActive})`:
  `foodId` tồn tại trong `foods`; `storageLocationId ∈ {fridge, freezer}`; `unit ∈ {days, weeks, months, years}` hoặc cả 3 giá trị null (không khuyến nghị);
  `0 < minValue <= maxValue <= 1000`; **duy nhất** một rule active cho cặp (`foodId`, `storageLocationId`) – kiểm tra trong transaction.
  Theo bảng tham chiếu `docs/SHELF_LIFE_RULES.md`.
- `setShelfLifeRuleActive({ruleId, isActive})` – xóa mềm (không xóa doc).

### 3.8 `getAiUsageOverview({period?})`
`collectionGroup("ai_usage").where("period","==",period).orderBy("receiptScanUsed","desc").limit(20)` → top user quét hóa đơn (kèm email),
tổng tháng; hôm nay: `sum(assistantUsed)` (PLAN 04). Hiển thị quota cấu hình từ `memberships`.

### 3.9 Index (`firestore.indexes.json`)
```json
{ "collectionGroup": "payments", "queryScope": "COLLECTION_GROUP",
  "fields": [{"fieldPath": "status", "order": "ASCENDING"}, {"fieldPath": "createdAt", "order": "DESCENDING"}] },
{ "collectionGroup": "payments", "queryScope": "COLLECTION_GROUP",
  "fields": [{"fieldPath": "status", "order": "ASCENDING"}, {"fieldPath": "paidAt", "order": "ASCENDING"}] },
{ "collectionGroup": "subscriptions", "queryScope": "COLLECTION_GROUP",
  "fields": [{"fieldPath": "status", "order": "ASCENDING"}, {"fieldPath": "endDate", "order": "ASCENDING"}] },
{ "collectionGroup": "ai_usage", "queryScope": "COLLECTION_GROUP",
  "fields": [{"fieldPath": "period", "order": "ASCENDING"}, {"fieldPath": "receiptScanUsed", "order": "DESCENDING"}] }
```
Và `fieldOverrides` cho collection-group single-field: `payments.createdAt` (DESC), `inventory_items.status`, `ai_usage.assistantDate` (ASC).
Kiểm tra `subscriptions (status, endDate)` có trùng index mà `expirePendingPayments` đang cần không, tránh tạo 2 lần.

### 3.10 Unit test
`validators.test.js`: membership (free price ≠ 0 bị từ chối, durationDays biên), shelf-life (min > max, unit lạ, bộ null hợp lệ), role/target tự khóa mình.

## 4. Flutter – `lib/features/admin/` (thay toàn bộ stub)

```
admin/
├── domain/
│   ├── entities/{admin_metrics.dart, admin_user.dart, admin_payment.dart, admin_ai_usage.dart, shelf_life_rule.dart, membership_plan_input.dart}
│   ├── repositories/admin_repository.dart
│   └── usecases/{get_admin_dashboard_metrics.dart, get_all_users.dart, toggle_user_status.dart, set_user_role.dart,
│                 get_all_payment_transactions.dart, update_membership_config.dart, manage_shelf_life_rules.dart,
│                 get_ai_usage_analytics.dart}
├── data/
│   ├── datasources/admin_remote_datasource.dart   # callables + direct reads of master data
│   ├── models/...
│   └── repositories/admin_repository_impl.dart
└── presentation/
    ├── pages/{admin_login_page.dart, admin_dashboard_page.dart, admin_users_page.dart, admin_memberships_page.dart,
    │          admin_ai_usage_page.dart, admin_shelf_life_rules_page.dart, admin_payments_page.dart}
    ├── providers/{admin_dashboard_provider.dart, admin_users_provider.dart, ...}   # 6 file đã có tên
    └── widgets/{admin_sidebar.dart, admin_shell.dart, admin_metric_card.dart, ai_quota_usage_chart.dart,
                 user_data_table.dart, membership_plan_form.dart, shelf_life_rule_dialog.dart, payment_status_chip.dart}
```
`admin/domain/entities/shelf_life_rule.dart` (stub, dùng `minDays/maxDays`) → **xóa**, dùng lại `inventory/domain/entities/shelf_life_rule.dart`
sau khi sửa entity đó theo DATABASE.md (`minValue/maxValue/unit`) – không giữ 2 entity cùng tên.
Thay `_PlaceholderScreen`/`_AdminShellScaffold` trong `app_router.dart` bằng page thật + `AdminShell`.

### 4.1 Đăng nhập admin (`AdminLoginPage`)
- Email + mật khẩu (`AppTextField`, `InputValidators`), dùng lại `LoginUseCase`.
- Sau đăng nhập: `getIdTokenResult(true)`; không có claim `admin` → `signOut()` + lỗi "Tài khoản không có quyền quản trị". Có → `go(adminDashboard)`.
- Không có Google Sign-In/đăng ký trên trang admin.
- Guard hiện có giữ nguyên logic, chỉ đổi nguồn `isAdminProvider` (mục 2.3).

### 4.2 Layout web
- `AdminShell`: sidebar cố định 240 px khi `context.isDesktop` (≥ 1024), `Drawer` khi nhỏ hơn; top bar có email admin + Đăng xuất.
- Web admin **không** dùng ScreenUtil design 390×844 cho kích thước bảng (sẽ phóng to quá mức) – dùng kích thước logic cố định + `LayoutBuilder`; vẫn dùng `AppColors`, `AppTextStyles`. Ghi chú ngoại lệ này vào FOORA_AI_CODE_RULES §3 cùng PR.
- Nội dung `ConstrainedBox(maxWidth: 1280)`.

### 4.3 Trang
| Trang | Nội dung | Hành động |
|---|---|---|
| Dashboard | 6 `AdminMetricCard` (users, premium active, households, món active, doanh thu tháng `CurrencyFormatter.formatVND`, lượt quét tháng); `LineChart` user mới 7 ngày | Làm mới (bỏ qua cache) |
| Users | `PaginatedDataTable`: tên, email, gói, vai trò, trạng thái, ngày tạo; ô tìm đầu email (debounce 400 ms) | Khóa/Mở khóa (confirm), Cấp/Gỡ admin (confirm, không áp dụng cho chính mình) |
| Memberships | 2 card Free/Premium với form `MembershipPlanForm` | Lưu (validate client giống server) |
| AI usage | Tổng lượt quét tháng, lượt trợ lý hôm nay, `BarChart` top 10 user, bảng top 20 | Chọn tháng |
| Shelf-life rules | Bảng lọc theo món + ngăn, cột min–max + đơn vị, active | Thêm/Sửa (`ShelfLifeRuleDialog`), Bật/Tắt |
| Payments | Bảng: thời gian, email, số tiền, mã tham chiếu, trạng thái (`PaymentStatusChip`), filter trạng thái | Xem chi tiết (dialog read-only) |

Mọi bảng: loading (`LoadingWidget`), trống (`EmptyStateWidget`), lỗi (`ErrorStateWidget` + Thử lại); thao tác thành công → `ToastHelper`.

## 5. Bảo mật – checklist
- [ ] Mọi callable admin gọi `verifyAdmin` dựa trên custom claim + `isActive`.
- [ ] Không mở Rules cho client đọc `users`/`payments` người khác.
- [ ] Admin không tự khóa/gỡ quyền chính mình.
- [ ] Mọi ghi có audit log.
- [ ] Gỡ admin → `revokeRefreshTokens` để mất quyền ngay.
- [ ] UI ẩn nút không phải là bảo mật (rule §34) – backend vẫn kiểm tra.

## 6. Test
- Functions: `validators.test.js`; test thủ công từng callable bằng user thường → `permission-denied`.
- Flutter unit: `AdminMetricsModel`, `AdminUserModel` (đã có test model – cập nhật field), membership form validator.
- Widget: `AdminLoginPage` hiển thị lỗi khi không có quyền (fake repository); `UserDataTable` nút khóa gọi use case đúng uid.

## 7. Triển khai web (Tech Lead)
`firebase.json` thêm:
```json
"hosting": {
  "public": "build/web",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [{"source": "**", "destination": "/index.html"}]
}
```
Build: `flutter build web --release --dart-define-from-file=.env.json` → `firebase deploy --only hosting`.
Trong Firebase Console → Authentication → Settings → Authorized domains: thêm domain hosting.
Kiểm tra giới hạn gói free Hosting trên trang pricing Firebase trước khi deploy.

## 8. Cập nhật tài liệu
- DATABASE.md: `admin_audit_logs`, `admin_cache` (server-only), custom claim `admin` là nguồn quyền; `users.role` chỉ để hiển thị.
- FUNCTIONS_GUIDE.md: danh sách callable admin mới (thay `toggleUserActive` bằng `setUserActive`, giữ hành vi), script `set_admin_claim`.
- FOORA_AI_CODE_RULES §3: ngoại lệ ScreenUtil cho web admin.
- `firestore.rules` (deny `admin_audit_logs`, `admin_cache`), `firestore.indexes.json`.

## 9. Definition of Done
- [ ] Đăng nhập admin bằng tài khoản có claim; tài khoản thường bị từ chối và đăng xuất.
- [ ] Dashboard hiển thị số liệu đúng (đối chiếu Emulator UI).
- [ ] Khóa user → user đó bị đăng xuất trên app trong vòng 1 phút, không đăng nhập lại được; mở khóa hoạt động lại.
- [ ] Sửa `foodLimit`/`receiptScanQuota` → app và backend áp dụng giá trị mới.
- [ ] CRUD shelf-life rule → item form tính hạn dùng theo rule mới.
- [ ] Danh sách payment lọc theo trạng thái, phân trang.
- [ ] Chạy trên Chrome; build web release thành công.

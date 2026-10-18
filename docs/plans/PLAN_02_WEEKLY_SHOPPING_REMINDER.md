# PLAN 02 – Nhắc đi chợ hằng tuần (push) + đồng bộ cài đặt thông báo

> Phần còn thiếu của chức năng 7 (Notifications): *"weekly 'time to go shopping' reminder"* và
> *"settings: alerts 1/3/7 days before expiry, daily reminder time"*.
> Phụ thuộc: PLAN 01 (đọc `shopping_list` và dùng `buildShoppingSuggestions`).

## 1. Hiện trạng (đã kiểm tra trong code)

- `NotificationSettingsNotifier` lưu cài đặt **chỉ trong SharedPreferences** (`pref_notif_*`) → Cloud Function **không đọc được**.
  Hệ quả: `checkExpiryDailyCron` (07:00 VN) gửi cho mọi người, bỏ qua 1/3/7 ngày và giờ nhắc người dùng chọn.
- FCM đã chạy: tạo doc `users/{uid}/notifications/{id}` → trigger `onNotificationCreated` → `FcmService.sendPushToUserDevices`.
- Cloud Scheduler đang dùng **2 job**. Free tier = **3 job / billing account / tháng**.

## 2. Thiết kế

### 2.1 Công nghệ

| Phần | Công nghệ |
|---|---|
| Lịch | 1 scheduled function v2 `onSchedule` chạy **mỗi giờ** (`"0 * * * *"`, `timeZone: "Asia/Ho_Chi_Minh"`) = job thứ 3 (free) |
| Gửi push | Ghi notification doc → trigger FCM sẵn có (không gọi FCM trực tiếp trong cron) |
| Lưu cài đặt | Field map `users/{uid}.notificationSettings` (owner ghi được, Rules validate) + SharedPreferences làm cache offline |

Vì sao chạy **mỗi giờ** thay vì 1 lần/tuần: user chọn **thứ + giờ** nhắc khác nhau; một job hằng giờ lọc đúng người cần nhắc, vẫn chỉ tốn 1 job Scheduler.
Chi phí: 720 lần chạy/tháng (free 2M invocation), mỗi lần đọc user đúng giờ đó (query có index).

### 2.2 Data model (cập nhật DATABASE.md)

Thêm vào `users/{userId}`:

| Field | Type | Required | Mô tả |
|---|---|---:|---|
| `notificationSettings` | Map | No | Không có = dùng mặc định bên dưới |
| `notificationSettings.pushEnabled` | Boolean | Yes | mặc định `true` |
| `notificationSettings.expiryAlertDays` | Array<Number> | Yes | tập con của `[1, 3, 7]`, mặc định `[1, 3]` |
| `notificationSettings.reminderHour` | Number | Yes | 0–23, giờ VN, mặc định 8 (giờ gửi nhắc hạn dùng **và** nhắc đi chợ) |
| `notificationSettings.shoppingReminderEnabled` | Boolean | Yes | mặc định `true` |
| `notificationSettings.shoppingReminderWeekday` | Number | Yes | 1 = Thứ Hai … 7 = Chủ nhật (ISO), mặc định 6 (Thứ Bảy) |
| `notificationSettings.updatedAt` | Timestamp | Yes | |

`reminderMinute` hiện có trong UI **bỏ** (job chạy theo giờ; giữ phút sẽ là hứa hẹn sai). Picker chỉ chọn giờ.
`soundEnabled` giữ local (chỉ ảnh hưởng channel trên máy, backend không cần).

Notification type mới: `shopping_reminder` (thêm vào bảng §13 DATABASE.md, `NotificationType` Dart + TS).
Payload FCM `data.type = "shopping_reminder"` → mở `/shopping-list`.

ID notification **xác định** để chạy lại không gửi trùng: `shopping_{YYYY}W{ISOweek}` (ví dụ `shopping_2026W42`).

### 2.3 Security Rules (`users/{userId}` update)

Thêm `notificationSettings` vào whitelist owner và validate kiểu:

```
allow update: if isOwner(userId)
  && changedKeys().hasOnly(['fullName', 'avatarUrl', 'email', 'updatedAt', 'notificationSettings'])
  && (!changedKeys().hasAny(['email']) || ( ...giữ nguyên điều kiện email hiện tại... ))
  && (!changedKeys().hasAny(['notificationSettings'])
      || validNotificationSettings(request.resource.data.notificationSettings));

function validNotificationSettings(s) {
  return s.keys().hasOnly(['pushEnabled', 'expiryAlertDays', 'reminderHour',
           'shoppingReminderEnabled', 'shoppingReminderWeekday', 'updatedAt'])
    && s.pushEnabled is bool
    && s.expiryAlertDays is list && s.expiryAlertDays.size() <= 3
    && s.reminderHour is int && s.reminderHour >= 0 && s.reminderHour <= 23
    && s.shoppingReminderEnabled is bool
    && s.shoppingReminderWeekday is int
    && s.shoppingReminderWeekday >= 1 && s.shoppingReminderWeekday <= 7;
}
```

(Ghi chú: Dart `int` gửi lên Firestore là integer nên `is int` đúng; không gửi `double`.)

### 2.4 Index

```json
{ "collectionGroup": "users", "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "notificationSettings.shoppingReminderEnabled", "order": "ASCENDING"},
    {"fieldPath": "notificationSettings.shoppingReminderWeekday", "order": "ASCENDING"},
    {"fieldPath": "notificationSettings.reminderHour", "order": "ASCENDING"} ] }
```

## 3. Backend

### 3.1 File

```
functions/src/notification/
├── schedulers/hourly_reminder_cron.ts        # NEW – the only new Scheduler job
├── services/shopping_reminder_service.ts     # NEW
├── services/reminder_planner.ts              # NEW – pure, unit-tested
└── services/notification_settings.ts         # NEW – parse + defaults (pure)
```

`hourly_reminder_cron.ts`:
```ts
export const hourlyReminderCron = onSchedule(
  {region: REGION, schedule: "0 * * * *", timeZone: "Asia/Ho_Chi_Minh"},
  async () => {
    const result = await ShoppingReminderService.run(new Date());
    logger.info(`[hourlyReminderCron] sent=${result.created} skipped=${result.skipped}`);
  }
);
```

### 3.2 `notification_settings.ts` (thuần)

```ts
export const DEFAULT_SETTINGS = {
  pushEnabled: true, expiryAlertDays: [1, 3], reminderHour: 8,
  shoppingReminderEnabled: true, shoppingReminderWeekday: 6,
} as const;
export function parseSettings(raw: unknown): NotificationSettings; // invalid -> defaults per field
export function vnClock(now: Date): {isoWeekday: number; hour: number; isoWeekKey: string};
```
`vnClock` dùng `Intl.DateTimeFormat("en-US", {timeZone: "Asia/Ho_Chi_Minh", weekday, hour: "2-digit", hourCycle: "h23"})`
(giống `calendarDateKey` trong `expiry_planner.ts`), tính ISO week theo ngày VN.

### 3.3 `ShoppingReminderService.run(now)`

1. `{isoWeekday, hour, isoWeekKey} = vnClock(now)`.
2. Query users: `notificationSettings.shoppingReminderEnabled == true && notificationSettings.shoppingReminderWeekday == isoWeekday && notificationSettings.reminderHour == hour`; lọc `isActive == true` trong code.
   Firestore không query được user **thiếu** field, nên mọi user phải có `notificationSettings` – client ghi mặc định ở lần mở app đầu tiên sau bản cập nhật (mục 4.2). User chưa mở app lại sẽ không nhận nhắc đi chợ cho tới khi mở app (chấp nhận được, ghi vào báo cáo).
3. Với mỗi user (giới hạn xử lý song song 20 bằng chunk):
   - bỏ qua nếu `pushEnabled == false`;
   - `householdId = activeHouseholdId`; nếu thiếu → skip;
   - đọc `shopping_list` pending (count + 3 tên đầu) và `buildShoppingSuggestions` (PLAN 01) top 3;
   - nếu cả hai rỗng → skip (không nhắc vô nghĩa);
   - `planShoppingReminder(...)` (thuần) tạo title/message:
     - title: `"Đến giờ đi chợ rồi! 🛒"`
     - message ví dụ: `"Danh sách có 4 món (Sữa tươi, Trứng gà, Cà chua…). Gợi ý thêm: Thịt heo."`
   - ghi `users/{uid}/notifications/shopping_{isoWeekKey}` bằng `create()`; lỗi `ALREADY_EXISTS` → skip (idempotent khi job retry).
4. Trigger `onNotificationCreated` tự gửi FCM. Cần thêm `type` vào `data` (FcmService đã có field `type`).

### 3.4 Cập nhật `checkExpiryDailyCron` để tôn trọng cài đặt (cùng PR)

Không thêm job mới: **chuyển logic nhắc hạn dùng vào `hourlyReminderCron`**, và đổi lịch `checkExpiryDailyCron` thành… xóa job đó.
Cụ thể:
- `hourlyReminderCron` mỗi giờ gọi thêm `ExpiryService.runForHour(now, hour)` chỉ cho user có `reminderHour == hour`
  (dùng `parseSettings`; user chưa có field → không nhận nhắc hạn dùng cho tới khi mở app, giống mục 3.3 bước 2).
- `expiry_planner` lọc theo `expiryAlertDays` của **từng user**: chỉ tạo `upcoming_expiration` khi `daysUntil ∈ expiryAlertDays`; `expiration_alert` (đã hết hạn, ngày đầu) luôn tạo nếu `pushEnabled`.
- Xóa export `checkExpiryDailyCron` → tổng job = **2** (`hourlyReminderCron`, `expirePendingPayments`), còn dư 1 job free.
- Giữ nguyên notification id ổn định của expiry planner (đã chống trùng).

Unit test planner hiện có (`expiry_service.test.js`) phải sửa theo hành vi lọc mới + thêm test `expiryAlertDays`.

## 4. Flutter

### 4.1 Domain/Data

- Entity `NotificationSettings` (domain, `notification` feature) thay cho `NotificationSettingsState` lưu trữ; state UI giữ trong provider.
- Repository `NotificationSettingsRepository`: `Stream<NotificationSettings> watch()`, `Future<void> save(NotificationSettings)`.
- Datasource: đọc/ghi `users/{uid}.notificationSettings` bằng `update({'notificationSettings': {...}, 'updatedAt': serverTimestamp})`; cache SharedPreferences cũ (`StorageKeys`) để mở app offline vẫn hiện đúng.
- Migration 1 lần: nếu Firestore chưa có field → ghi giá trị từ SharedPreferences hiện tại (map: `expiryAlert1Day/3Days/7Days` → `expiryAlertDays`, `reminderHour`), mặc định shopping Thứ Bảy.

### 4.2 Khi nào ghi mặc định

Trong `NotificationOpenListener`/khởi tạo sau đăng nhập: nếu doc user không có `notificationSettings` → `save(defaults merged with local prefs)`. Đảm bảo mọi user active đều được cron nhìn thấy.

### 4.3 UI `notification_settings_page.dart`

- Giữ các switch 1/3/7 ngày, đổi time picker → **chọn giờ** (00–23).
- Thêm khối "Nhắc đi chợ hằng tuần": switch bật/tắt + chọn thứ (T2…CN) dùng `BottomSheetHelper.showSelect`.
- Mỗi thay đổi lưu ngay (debounce 500 ms bằng `Debouncer`), lỗi → toast + hoàn tác UI.
- Dòng mô tả: "Thông báo được gửi khoảng {giờ}:00 (giờ Việt Nam)".

### 4.4 Tap-through

`notificationOpenLocation(data)`: nếu `data['type'] == 'shopping_reminder'` → `AppRouteNames.shoppingList`.
In-app inbox: `NotificationTile` icon `LucideIcons.shoppingCart` cho type mới; tap → shopping list.

## 5. Test

- Functions: `notification_settings.test.js` (parse mặc định, giá trị sai), `vnClock` (biên 23:59 UTC ↔ 06:59 VN, đổi tuần ISO), `reminder_planner.test.js` (message có/không suggestion, cắt "…" sau 3 tên), cập nhật `expiry_service.test.js`.
- Flutter: unit migration prefs → settings; widget test settings page chọn Thứ Bảy gọi `save` với `shoppingReminderWeekday: 6`.
- Thủ công: Functions shell `hourlyReminderCron()` với user đặt giờ hiện tại → nhận push trên máy thật; chạy lại lần 2 không có push trùng.

## 6. Cập nhật tài liệu

- DATABASE.md: `users.notificationSettings`, type `shopping_reminder`, ghi chú id `shopping_{YYYY}W{ww}`.
- FUNCTIONS_GUIDE.md: thay `checkExpiryDailyCron` bằng `hourlyReminderCron` trong bảng; ghi rõ "tổng 2 Scheduler job".
- `firestore.rules`, `firestore.indexes.json`.

## 7. Definition of Done

- [ ] Đổi cài đặt trên máy A → field Firestore cập nhật, mở máy B (cùng tài khoản) thấy giống.
- [ ] Đúng thứ + giờ đã chọn nhận push "Đến giờ đi chợ"; tap mở danh sách đi chợ.
- [ ] Không có push khi danh sách + gợi ý đều rỗng, hoặc `pushEnabled = false`.
- [ ] Nhắc hạn dùng chỉ gửi theo 1/3/7 ngày đã chọn, đúng giờ đã chọn.
- [ ] Số Scheduler job sau deploy ≤ 3 (kiểm tra Cloud Console → Cloud Scheduler).

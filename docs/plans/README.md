# FOORA – Kế hoạch triển khai các chức năng chưa làm

Thư mục này chứa **một file plan cho mỗi chức năng còn ⏳** trong `docs/PRM393_Project.docx`.
Mỗi plan là "hợp đồng" để code: công nghệ + phiên bản, cách setup, data model, Security Rules,
Cloud Functions, cấu trúc file Flutter, flow UI, edge case, test và checklist hoàn thành.
Khi code, làm **đúng theo plan**; nếu cần lệch thì sửa plan trước rồi mới code.

| # | File | Chức năng trong đề | Phụ thuộc |
|---|---|---|---|
| 01 | [PLAN_01_SHOPPING_LIST.md](./PLAN_01_SHOPPING_LIST.md) | 5. Shopping list + "Frequently bought" | — |
| 02 | [PLAN_02_WEEKLY_SHOPPING_REMINDER.md](./PLAN_02_WEEKLY_SHOPPING_REMINDER.md) | 7. Nhắc đi chợ hằng tuần (+ đồng bộ cài đặt thông báo) | 01 |
| 03 | [PLAN_03_NEARBY_STORES_MAP.md](./PLAN_03_NEARBY_STORES_MAP.md) | 8. Map siêu thị / chợ gần đây | 01 (nút "Đi chợ") |
| 04 | [PLAN_04_AI_VOICE_ASSISTANT.md](./PLAN_04_AI_VOICE_ASSISTANT.md) | 9. Trợ lý AI giọng nói (cập nhật kho + gợi ý món) | 01 |
| 05 | [PLAN_05_HOUSEHOLD_SHARING.md](./PLAN_05_HOUSEHOLD_SHARING.md) | Household sharing (mã mời 6 ký tự) | — |
| 06 | [PLAN_06_WASTE_STATISTICS.md](./PLAN_06_WASTE_STATISTICS.md) | Waste statistics | — |
| 07 | [PLAN_07_WEB_ADMIN.md](./PLAN_07_WEB_ADMIN.md) | Web admin dashboard + đăng nhập admin | — |

**Thứ tự đề xuất:** 05 → 01 → 02 → 04 → 03 → 06 → 07.
05 làm trước vì shopping list và AI đều "dùng chung trong household"; làm sau sẽ phải sửa lại rules.

---

## 1. Quyết định công nghệ dùng chung (đã kiểm tra 2026-10-18)

Tất cả đều **miễn phí**, build được **APK release** từ Android Studio / `flutter build apk`.

| Mục đích | Công nghệ | Phiên bản chốt | Ghi chú bắt buộc |
|---|---|---|---|
| Bản đồ | `flutter_map` + `latlong2` | `flutter_map: ^8.3.2`, `latlong2: ^0.9.1` | Tile OSM `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, **bắt buộc** `userAgentPackageName: 'com.foora.foora'` + attribution hiển thị; cache built-in từ 8.2.0 |
| Vị trí | `geolocator` | `^14.1.1` | `compileSdk` 35 (Flutter mặc định ≥ 35), xin `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` cùng lúc |
| Mở chỉ đường | `url_launcher` + Google Maps URLs | `^6.3.3` | `https://www.google.com/maps/dir/?api=1&destination=lat,lng` – **không cần API key** |
| Dữ liệu cửa hàng | Overpass API (OSM) | — | Gọi **từ Cloud Function** (cache Firestore), User-Agent riêng, < 10.000 req/ngày |
| Giọng nói → chữ | `speech_to_text` (Android SpeechRecognizer) | `^7.5.0` | `RECORD_AUDIO` + `<queries>` `android.speech.RecognitionService`; `localeId: 'vi_VN'` |
| AI | Gemini API qua `@google/genai` (đã có `^2.21.0`) | model `gemini-3.8-flash` | Chỉ gọi từ Cloud Functions; structured output (`responseSchema`) |
| Biểu đồ | `fl_chart` | `^1.2.0` | MIT, chạy Android + Web |
| Push | FCM (đã có) | — | Tạo `users/{uid}/notifications/*` → trigger `onNotificationCreated` gửi FCM |
| Lịch chạy | Cloud Functions v2 `onSchedule` (Cloud Scheduler) | — | **Free 3 job / billing account / tháng**, job thứ 4 trở đi ~0,10 USD/job/tháng |

### 1.1 Ràng buộc chi phí "free" phải giữ

- **Cloud Scheduler:** hiện có 2 job (`checkExpiryDailyCron`, `expirePendingPayments`). Plan 02 thêm `hourlyReminderCron` (chạy mỗi giờ) và **gộp** nhắc hạn dùng vào đó rồi xóa `checkExpiryDailyCron` → tổng còn **2 job**, dưới mức free 3 job.
  **Không** tạo `resetMonthlyQuotaCron` như FUNCTIONS_GUIDE gợi ý: `ReceiptQuotaService` đã tự reset theo `period`, cron đó chỉ tốn job thứ 4.
- **Gemini free tier:** Google không công bố bảng cố định; mức cộng đồng theo dõi cho 3.x Flash ≈ **10 request/phút, ~1.500 request/ngày cho cả project**
  (chia chung cho quét hóa đơn + trợ lý AI). Xem số thật của project tại <https://aistudio.google.com/rate-limit>. Hệ quả cho code:
  - luôn retry có backoff với 429/503 (pattern đã có trong `receipt_parser.ts`),
  - quota theo ngày cho từng user (plan 04) để một người không ăn hết quota project,
  - free tier **dùng dữ liệu để cải thiện sản phẩm** → không gửi email, họ tên, id người dùng lên Gemini; chỉ gửi tên/số lượng thực phẩm.
- **OSM tiles:** cho phép dùng trong app native nếu có User-Agent riêng, attribution rõ, tôn trọng cache, **không** tải trước/offline. Vi phạm có thể bị chặn không báo trước.
- **Overpass:** < ~10.000 request và < 1 GB/ngày tính **tổng mọi user của app**; 429/504 → chờ ≥ 30 s. Vì vậy gọi qua Cloud Function có cache.

### 1.2 Quy tắc chung khi code (nhắc lại từ FOORA_AI_CODE_RULES)

- Clean Architecture: `domain` (entity, repository interface, use case – Dart thuần) → `data` (model, datasource, repository impl) → `presentation` (page, widget, provider Riverpod).
- Không gọi Firestore/Firebase trong page/widget; không gọi Gemini/Overpass từ Flutter.
- Thao tác ảnh hưởng **quota, membership, household access, inventory count** → Cloud Function (callable) + Security Rules chặn client.
- Backend 3 tầng: callable mỏng (< 30 dòng) → service → infra. Lỗi trả về `never`. Không hardcode collection: thêm vào `functions/src/constants/collections.ts` **và** `lib/core/constants/firestore_constants.dart`.
- Quyền gói (Free/Premium) luôn qua `MembershipService.resolveMembershipId` + `MembershipService.getLimits`; mọi hạn mức mới đặt trong `memberships/{id}`.
- UI: `AppColors`, ScreenUtil (`.w/.h/.r/.sp`), `SubpageLayout`, `AppHeader`, `ToastHelper`, `DialogHelper`, `LoadingWidget`/`EmptyStateWidget`/`ErrorStateWidget`, comment tiếng Anh.
- Mỗi plan có mục "Cập nhật tài liệu": DATABASE.md, FUNCTIONS_GUIDE.md, `firestore.rules`, `firestore.indexes.json` phải sửa **cùng PR**.
- Trước khi xong: `dart format lib test`, `flutter analyze`, `flutter test`, `cd functions && npm run lint && npm test`, chạy flow trên Emulator, build `flutter build apk --release --dart-define-from-file=.env.json` và test trên **máy thật**.

### 1.3 Thay đổi AndroidManifest tổng hợp (sau khi làm đủ các plan)

```xml
<!-- Plan 03: location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- Plan 01/04: voice input -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<queries>
    <!-- existing PROCESS_TEXT intent stays -->
    <intent>
        <action android:name="android.speech.RecognitionService"/>
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <data android:scheme="https"/>
    </intent>
</queries>
```

Không thêm `ACCESS_BACKGROUND_LOCATION` (app chỉ dùng vị trí khi đang mở màn Map).

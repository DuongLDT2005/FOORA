# FOORA – Cấu trúc Dự án (Project Structure)

Tài liệu này định nghĩa toàn bộ cấu trúc thư mục, quy ước kiến trúc (Clean Architecture) và chức năng của từng file trong dự án **FOORA**.

---

## 1. Cấu trúc Thư mục Gốc (Root Structure)

```text
foora/
├── android/            # Mã nguồn native Android
├── ios/                # Mã nguồn native iOS
├── web/                # Cấu hình Web app
├── test/               # Unit test & Widget test
├── lib/                # Mã nguồn chính Flutter (core, shared, features)
├── functions/          # Backend Cloud Functions (TypeScript)
├── assets/             # Hình ảnh, icon, font tĩnh
├── docs/               # Toàn bộ tài liệu kiến trúc & quy chuẩn dự án
├── firebase.json       # Cấu hình dịch vụ Firebase & Emulators
├── firestore.rules     # Bảo mật phân quyền Firestore Database
├── firestore.indexes.json # Cấu hình composite indexes cho Firestore
├── storage.rules       # Bảo mật lưu trữ Cloud Storage
└── pubspec.yaml        # Quản lý dependencies và cấu hình Flutter app
```

### Chi tiết thư mục `docs/`

| File Tài liệu | Mục đích & Trách nhiệm |
| :--- | :--- |
| **[`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md)** | Tổng quan hệ thống, bài toán, giải pháp AI/OCR, phân quyền Admin & Member. |
| **[`PROJECT_STRUCTURE.md`](./PROJECT_STRUCTURE.md)** | Bản đồ cấu trúc thư mục, trách nhiệm từng file theo Clean Architecture. |
| **[`FOORA_AI_CODE_RULES.md`](./FOORA_AI_CODE_RULES.md)** | Bộ quy tắc bắt buộc khi viết code (Clean Architecture, Riverpod, Firebase, UI). |
| **[`DATABASE.md`](./DATABASE.md)** | Thiết kế lược đồ Firestore Collections, Subcollections và Cloud Storage. |
| **[`DEVELOPMENT_WORKFLOW.md`](./DEVELOPMENT_WORKFLOW.md)** | Quy trình làm việc, môi trường DEV/PROD, lệnh chạy Emulator. |
| **[`FUNCTIONS_GUIDE.md`](./FUNCTIONS_GUIDE.md)** | Cấu trúc chi tiết Cloud Functions, các loại trigger/callable, quy tắc code & mẫu code chuẩn. |
| **[`SETUP.md`](./SETUP.md)** | Hướng dẫn cài đặt môi trường, Flutter SDK, Node.js, Firebase CLI. |

---

## 2. Cấu trúc Tổng thể `lib/`

```text
lib/
├── core/       # Hạ tầng kỹ thuật, cấu hình môi trường, dịch vụ toàn cục & tiện ích
├── shared/     # Thành phần UI dùng chung, components, extensions, helpers
└── features/   # 11 module nghiệp vụ độc lập theo Clean Architecture
```

---

## 3. Chi tiết tầng `lib/core/`

Chứa toàn bộ hạ tầng kỹ thuật nền tảng, không phụ thuộc vào bất kỳ feature nào.

```text
lib/core/
├── config/       # Quản lý biến môi trường và cấu hình động
├── constants/    # Hằng số Firestore, Storage, Key lưu trữ & App
├── errors/       # Định nghĩa Exception và Failure (Clean Error Handling)
├── firebase/     # Khởi tạo SDK, kết nối Emulator & Riverpod providers
├── routes/       # Cấu hình GoRouter, Route Guards & Phân quyền Web/Mobile
├── services/     # Dịch vụ kỹ thuật (Storage, Connectivity, Push Notification)
├── theme/        # Design System (Màu sắc, Typography, ThemeData Light/Dark)
└── utils/        # Tiện ích thuần túy (Xử lý Ngày FEFO, Tiền tệ VND, Validation, Logger)
```

### Bảng chức năng các file trong `lib/core/`

| Thư mục | File | Chức năng & Trách nhiệm |
| :--- | :--- | :--- |
| **`config`** | `environment.dart` | Enum `Environment` (`dev`, `prod`) và parser cờ `--dart-define` (`AppEnv`). |
| | `app_config.dart` | Singleton lưu trạng thái cấu hình runtime (`useFirebaseEmulator`, `emulatorHost`, `apiBaseUrl`). |
| **`constants`** | `app_constants.dart` | Hằng số app chung (tên app, timeout, page size, `asia-southeast1`, định dạng ngày mặc định). |
| | `app_enums.dart` | Tập hợp Type-Safe Enums chuẩn hóa theo `DATABASE.md` (`UserRole`, `MembershipTier`, `StorageLocationCode`, `InventoryItemSource`, `ReceiptStatus`, `NotificationType`, `AppPlatform`, `SubscriptionStatus`, `PaymentStatus`). |
| | `firestore_constants.dart` | Hằng số tên collection & document cố định Firestore (`users`, `households`, `foods`, `aiUsageCurrentDoc`,...). |
| | `storage_constants.dart` | Hằng số đường dẫn thư mục Cloud Storage (`receipts`, `foods`). |
| | `storage_keys.dart` | Hằng số key cho bộ nhớ local `SharedPreferences` (`activeHouseholdId`, `themeMode`, `isFirstLaunch`). |
| **`errors`** | `exceptions.dart` | Các class Exception tầng Data với factory mapper `fromFirebase` và thông báo lỗi tiếng Việt. |
| | `failures.dart` | Các class Failure tầng Domain (`Failure.fromException`) ngăn rò rỉ SDK exception ra UI. |
| **`firebase`** | `firebase_initializer.dart` | Khởi tạo Firebase đa nền tảng, tự động trỏ Local Emulator khi chạy DEV. |
| | `firebase_providers.dart` | Riverpod providers cho các instance Firebase SDK (`auth`, `firestore`, `functions`, `storage`, `messaging`). |
| | `auth_session_providers.dart` | Quản lý phiên đăng nhập: tách raw stream (`currentUserDocStreamProvider`) và logic (`isAdminProvider`). |
| **`routes`** | `route_names.dart` | Hằng số định danh URL cho Mobile (`/home`, `/inventory`,...) và Web Admin (`/admin/dashboard`,...). |
| | `app_router.dart` | Cấu hình `GoRouter`, `RouterNotifier` đa luồng, Auth/Admin Route Guard, Navigation Shell và trang 404. |
| **`services`** | `connectivity_service.dart` | Theo dõi kết nối Internet thời gian thực (`connectivity_plus`), cung cấp `isConnectedProvider`. |
| | `notification_service.dart` | Xử lý nhận Push Notification FCM và handler `@pragma('vm:entry-point')` chạy nền. |
| | `storage_service.dart` | Wrapper cho `SharedPreferences` lưu trữ cài đặt phi nhạy cảm, cung cấp `storageServiceProvider`. |
| **`theme`** | `app_colors.dart` | Bảng màu thiết kế (Emerald chủ đạo, Slate trung tính, Amber cảnh báo, Red hết hạn, `slate900` nền dark). |
| | `app_text_styles.dart` | Typography chuẩn Material 3 sử dụng font `Inter` (nội dung) và `Lexend` (tiêu đề). |
| | `app_theme.dart` | Cấu hình hoàn chỉnh Material 3 `lightTheme` và `darkTheme`. |
| **`utils`** | `date_formatter.dart` | Định dạng ngày `dd/MM/yyyy`, tính số ngày hạn FEFO (`getDaysUntilExpiry`, `getExpiryStatus`), câu mô tả tương đối. |
| | `currency_formatter.dart` | Định dạng tiền tệ Việt Nam (`formatVND` hiển thị `'150.000 ₫'`, số 0 thành `'Miễn phí'`). |
| | `input_validators.dart` | Validation kiểm tra Email, Mật khẩu, Trường bắt buộc, Số lượng dương lớn hơn 0. |
| | `app_logger.dart` | Ghi log emoji theo cấp độ (`d`, `i`, `w`, `e`), tự động tắt trong bản Release (`!kReleaseMode`). |

---

## 4. Chi tiết tầng `lib/shared/`

Chứa các thành phần giao diện, tiện ích mở rộng và helper có thể tái sử dụng ở nhiều màn hình khác nhau.

```text
lib/shared/
├── widgets/      # Atomic UI: Các widget cơ bản không chứa business logic
├── components/   # Molecule UI: Các khối UI phức hợp có logic tương tác nội bộ
├── extensions/   # Tiện ích mở rộng cú pháp cho BuildContext, String
├── helpers/      # Helper điều hướng Dialog, Debouncer tìm kiếm
└── models/       # Data models dùng chung (Pagination, Dropdown items)
```

### Bảng chức năng các thành phần trong `lib/shared/`

| Thư mục | File | Chức năng & Trách nhiệm |
| :--- | :--- | :--- |
| **`widgets`** | `app_button.dart` | `PrimaryButton` (nút chính bo 16px kèm loading), `SecondaryButton`, `DangerButton`, `AppFloatingActionButton`. |
| | `app_text_field.dart` | `AppTextField` (input chữ in hoa, required sao đỏ), `AppDropdown<T>`, `AppPercentageSlider` (thanh trượt 0-100%). |
| | `app_card.dart` | `FeatureCard` (thẻ menu/tính năng có icon), `StatisticCard` (thẻ thống kê Dashboard: `good`, `warning`, `expired`). |
| | `status_badge.dart` | `StatusBadge` (nhãn trạng thái bo 8px: Hết hạn, Sắp hết, Premium), `CategoryAvatar` (khung icon danh mục). |
| | `app_header.dart` | `AppHeader` (AppBar font Lexend, hỗ trợ `isDark`), `AppBottomSheet` (modal sheet kéo), `StickyBottomActions`, `AppToast`. |
| | `loading_widget.dart` | `AppLoadingSpinner`, `FullScreenLoader`, `LoadingWidget` (vòng xoay tải trang). |
| | `empty_state.dart` | `EmptyStateWidget` (giao diện placeholder khi danh sách rỗng). |
| | `error_state.dart` | `ErrorStateWidget` (giao diện báo lỗi kèm nút Thử lại). |
| **`components`** | `app_shimmer.dart` | Hiệu ứng Skeleton Shimmer loading quét gradient mượt mà (`AppShimmer.box`, `AppShimmer.circle`). |
| | `app_search_bar.dart` | Thanh tìm kiếm bo 16px tích hợp `Debouncer`, icon kính lúp và nút xóa text tự động. |
| | `app_segmented_control.dart` | Bộ nút gạt phân loại tab mềm (Ngăn mát / Ngăn đông) hỗ trợ icon và badge số lượng. |
| | `app_dialog.dart` | Khung Dialog pop-up Material 3 bo góc 20px, icon tiêu đề và 2 nút hành động. |
| **`extensions`** | `context_extensions.dart` | Mở rộng `BuildContext`: `theme`, `colorScheme`, `textTheme`, `screenHeight`, `isMobile`, `showToast()`. |
| | `string_extensions.dart` | Mở rộng `String`: `capitalize()`, `toTitleCase()`, `obscureEmail()` (*d***5@gmail.com*), `isValidEmail`. |
| **`helpers`** | `debouncer.dart` | Cơ chế hoãn thực thi tìm kiếm (Debounce 300–500ms khi người dùng gõ phím). |
| | `dialog_helper.dart` | Tiện ích gọi Dialog: `showConfirmDialog()`, `showDeleteDialog()`, `showInfoDialog()`. |

---

## 5. Chi tiết 11 Feature Modules (`lib/features/`)

Mỗi feature hoạt động độc lập và tuân thủ tuyệt đối quy chuẩn 3 tầng **Clean Architecture**:

```text
features/{feature_name}/
├── data/           # Tầng dữ liệu ngoại vi (Firestore, API, Local Storage)
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/         # Tầng nghiệp vụ thuần túy (Không phụ thuộc Flutter SDK / Firebase)
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
└── presentation/   # Tầng hiển thị giao diện & quản lý trạng thái
    ├── pages/
    ├── widgets/
    └── providers/
```

### Bảng phân bổ 11 Feature Modules

| # | Feature | Mục đích & Nghiệp vụ chính | Các file chính |
| :---: | :--- | :--- | :--- |
| **1** | **`auth`** | Đăng nhập & Đăng ký (2 tab trên 1 page), quên mật khẩu, đăng xuất. | `user.dart`, `user_model.dart`, usecases (`login`, `register`, `logout`), pages (`auth_page.dart`, `forgot_password_page.dart`), `auth_provider.dart`. |
| **2** | **`profile`** | Xem và cập nhật thông tin cá nhân, avatar, cài đặt tài khoản. | `profile.dart`, `profile_model.dart`, `get_profile.dart`, `update_profile.dart`, `profile_page.dart`, `profile_provider.dart`. |
| **3** | **`membership`** | Quản lý gói thành viên (Free / Premium), gói đăng ký (Subscription). | `membership_plan.dart`, `membership_plan_model.dart`, `subscription.dart`, `subscription_model.dart`, `get_membership_plans.dart`, `membership_page.dart`, `membership_provider.dart`. |
| **4** | **`payment`** | Tích hợp In-App Purchase (IAP Google Play / App Store), xem lịch sử giao dịch. | `payment_transaction.dart`, `payment_transaction_model.dart`, `create_payment_intent.dart`, `payment_page.dart`, `payment_history_page.dart`. |
| **5** | **`household`** | Quản lý gia đình/nhóm: tạo kho chung (Scope hiện tại), tham gia qua mã mời (Hạ tầng cho sau). | `household.dart`, `household_model.dart`, `invite_member.dart`, `household_page.dart`, `household_provider.dart`. |
| **6** | **`inventory`** | Quản lý kho thực phẩm trong tủ lạnh (`inventory_items`), theo dõi hạn dùng FEFO & Master Data Catalog (`foods`, `food_categories`, `storage_locations`, `shelf_life_rules`). | `inventory_item.dart`, `inventory_item_model.dart`, `food.dart`, `food_model.dart`, `food_category.dart`, `food_category_model.dart`, `storage_location.dart`, `storage_location_model.dart`, `shelf_life_rule.dart`, `shelf_life_rule_model.dart`, `inventory_page.dart`, `inventory_item_card.dart`. |
| **7** | **`receipt`** | Chụp/quét hóa đơn bằng Camera OCR (ML Kit) & trích xuất AI. | `receipt.dart`, `receipt_model.dart`, `receipt_item.dart`, `receipt_item_model.dart`, `scan_receipt.dart`, `receipt_scan_page.dart`, `receipt_review_page.dart`. |
| **8** | **`notification`** | Danh sách thông báo đẩy cảnh báo thực phẩm sắp hết hạn & Quản lý thiết bị (Devices). | `app_notification.dart`, `app_notification_model.dart`, `device.dart`, `device_model.dart`, `get_notifications.dart`, `notification_page.dart`. |
| **9** | **`ai`** | Trò chuyện với Trợ lý AI (gợi ý món ăn, tra cứu dinh dưỡng, quản lý quota). | `ai_usage_quota.dart`, `ai_usage_quota_model.dart`, `ai_chat_message.dart`, `send_ai_query.dart`, `get_ai_usage_quota.dart`, `ai_chat_page.dart`. |
| **10** | **`home`** | Trang chủ tổng quan: tóm tắt kho, cảnh báo thực phẩm cấp bách, gợi ý nhanh. | `dashboard_summary.dart`, `dashboard_summary_model.dart`, `get_dashboard_summary.dart`, `home_page.dart`, `dashboard_summary_card.dart`, `home_provider.dart`. |
| **11** | **`admin`** | Web Dashboard quản trị: Users, Memberships, AI Quota, Shelf-Life Rules, Payments. | `admin_metrics.dart`, `admin_metrics_model.dart`, `admin_user.dart`, `admin_user_model.dart`, 7 admin pages, 6 admin providers. |

---

## 6. Backend Cloud Functions (`functions/src/`)

Chứa mã nguồn Node.js/TypeScript chạy trên Firebase Cloud Functions đảm bảo bảo mật và tự động hóa:

| Module Function | Trách nhiệm Backend |
| :--- | :--- |
| **`auth/`** | Khởi tạo document `users/{userId}` khi người dùng mới đăng ký qua Firebase Auth trigger. |
| **`inventory/`** | Cron job tự động quét hạn sử dụng hàng ngày và gửi cảnh báo FEFO. |
| **`receipt/`** | Gọi Gemini API parse hóa đơn từ văn bản OCR thô, chống giả mạo client. |
| **`ai/`** | Proxy gọi Gemini API, ghi nhận số lần dùng và kiểm tra quota gói thành viên. |
| **`notification/`** | Gửi tin nhắn đẩy FCM cho toàn bộ thiết bị trong Household khi có sự kiện quan trọng. |
| **`membership/`** | Quản lý nâng cấp/hạ cấp gói, reset quota quét hàng tháng. |
| **`payment/`** | Xác thực biên lai In-App Purchase (IAP Google Play / App Store), ghi payments và kích hoạt subscription. |
| **`household/`** | `createHousehold` (Scope hiện tại), chuẩn bị hạ tầng `joinHousehold` cho giai đoạn sau. |
| **`admin/`** | Quản lý phân quyền (Custom Claims), khóa tài khoản tức thì (`revokeRefreshTokens`), xuất báo cáo. |

---

## 7. Nguyên tắc Chiều Phụ thuộc (Clean Architecture Flow)

```text
UI (Pages & Widgets)
       ↓
State Provider (Riverpod)
       ↓
Use Case (Domain)
       ↓
Repository Interface (Domain)
       ↑ (implements)
Repository Implementation (Data)
       ↓
Data Source (Remote / Local)
       ↓
Firebase SDK / SharedPreferences / External API
```

### 4 Luật Bất Di Bất Dịch:
1. **Domain là trung tâm**: Tầng `domain/` tuyệt đối không import Flutter UI, Firebase SDK hay thư viện bên ngoài.
2. **Không query trực tiếp**: Tầng `presentation/` (Pages, Widgets) không bao giờ gọi trực tiếp Firestore/HTTP. Mọi thao tác phải thông qua Provider ➔ UseCase ➔ Repository.
3. **Phân biệt UI**: Widget đặc thù thuộc về `features/{feature}/presentation/widgets/`, widget/component dùng chung thuộc về `lib/shared/`.
4. **Bảo mật Backend**: Mọi hạn mức gói (Quota), vai trò Admin và thuật toán AI nhạy cảm đều phải được xác thực ở Cloud Functions và Security Rules.

# PLAN 01 – Danh sách đi chợ (Shopping list) + gợi ý "Hay mua"

> Chức năng 5 trong `PRM393_Project.docx` (tương ứng "Shopping cart" của project mẫu).
> Phụ thuộc: nên làm sau PLAN 05 (household sharing) vì danh sách dùng chung cả household.
> Được dùng bởi: PLAN 02 (nhắc đi chợ), PLAN 03 (nút "Đi chợ" → Map), PLAN 04 (AI thêm nguyên liệu thiếu).

## 1. Phạm vi (đúng theo đề, không thêm)

1. Danh sách đi chợ **chung cho cả household**, realtime cho mọi thành viên.
2. Thêm món: **thủ công**, **bằng giọng nói**, **từ gợi ý "Hay mua"**, **từ gợi ý món ăn của AI** (PLAN 04 gọi vào).
3. Gợi ý "Hay mua" dựa trên lịch sử mua: tần suất, khoảng cách mua lại trung bình, tồn kho hiện tại. Mỗi gợi ý có **lý do**,
   ví dụ: *"Bạn thường mua Sữa tươi mỗi ~7 ngày, lần cuối 8 ngày trước, đã hết trong tủ."*
4. Tick **"Đã mua"** → món chuyển vào inventory, **hạn dùng tự tính** từ shelf-life rules.
5. Nút **"Đi chợ"** mở màn Map (PLAN 03).

Ngoài phạm vi: giá tiền, chia danh sách theo cửa hàng, nhiều danh sách.

## 2. Công nghệ

| Phần | Công nghệ | Lý do |
|---|---|---|
| Lưu trữ realtime | Cloud Firestore (đã có) | `snapshots()` cho realtime giữa các thành viên, free tier đủ dùng |
| Chuyển "Đã mua" → kho | Cloud Function callable `completeShoppingItems` | Phải kiểm tra `foodLimit`, tăng `activeItemCount`, tính hạn dùng → chỉ backend được làm (Rules chặn client tạo `inventory_items`) |
| Gợi ý "Hay mua" | Cloud Function callable `getShoppingSuggestions` + thuật toán thuần TS | Một nguồn logic duy nhất, PLAN 02 dùng lại cho push; unit test bằng `node --test` |
| Nhập giọng nói | `speech_to_text: ^7.5.0` (Android SpeechRecognizer, Google app) | Free, chạy offline nếu máy đã tải gói tiếng Việt; không tốn quota Gemini |
| Tách "2 hộp sữa" | Parser rule-based Dart thuần (domain) | Không tốn AI, kết quả xác định, có bước xác nhận trước khi lưu |

### 2.1 Setup `speech_to_text` (dùng chung với PLAN 04)

`pubspec.yaml` đã có `speech_to_text: ^7.4.0` → nâng lên `^7.5.0`.

`android/app/src/main/AndroidManifest.xml` (thêm, không xóa gì):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService"/>
    </intent>
</queries>
```

(Đặt `<intent>` mới vào **cùng** khối `<queries>` đang có `PROCESS_TEXT`.)

Tạo service hạ tầng dùng chung **`lib/core/services/voice_input_service.dart`** (không phụ thuộc feature):

```dart
/// Wraps speech_to_text so features never touch the plugin directly.
class VoiceInputService {
  VoiceInputService(this._speech);
  final SpeechToText _speech;

  /// Returns false when the device has no recognizer or mic permission is denied.
  Future<bool> initialize() => _speech.initialize(
        onError: (e) => AppLogger.w('STT error: ${e.errorMsg}'),
        debugLogging: !kReleaseMode,
      );

  /// Vietnamese if installed, otherwise the device default locale.
  Future<String?> resolveLocaleId() async {
    final locales = await _speech.locales();
    final vi = locales.where((l) => l.localeId.toLowerCase().startsWith('vi'));
    return vi.isNotEmpty ? vi.first.localeId : (await _speech.systemLocale())?.localeId;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
    required String? localeId,
  }) {
    return _speech.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stop() => _speech.stop();
  bool get isListening => _speech.isListening;
}
```

Provider: `voiceInputServiceProvider = Provider((ref) => VoiceInputService(SpeechToText()))` trong `lib/core/services/`.

Quy tắc để **kết quả chính xác**:
- Hiện chữ đang nhận dạng (partial) ngay trên UI; khi `isFinal` → đổ vào ô nhập/ bảng xác nhận, **người dùng sửa được trước khi lưu**. Không bao giờ lưu thẳng kết quả STT.
- `initialize()` tự xin quyền micro. Nếu trả `false`: toast "Thiết bị chưa hỗ trợ nhận dạng giọng nói, vui lòng nhập tay" và giữ nút nhập tay.
- Nếu `resolveLocaleId()` không có `vi*`: hiện hướng dẫn "Cài tiếng Việt: Google app → Cài đặt → Giọng nói → Ngôn ngữ" và vẫn cho dùng locale mặc định.
- Android tự dừng sau ~5 s im lặng và luôn có tiếng beep: đây là giới hạn nền tảng, không cố "sửa".
- Test trên **máy thật** (emulator cần system image có Google Play + Google app).

## 3. Data model (cập nhật DATABASE.md)

### 3.1 Subcollection mới `households/{householdId}/shopping_list/{shoppingItemId}`

| Field | Type | Required | Mô tả |
|---|---|---:|---|
| `name` | String | Yes | Tên hiển thị (user nhập / gợi ý) |
| `normalizedName` | String | Yes | `StringUtils.normalize(name)` – không dấu, lowercase |
| `foodId` | String | No | Món trong master `foods` nếu khớp autocomplete |
| `categoryId` | String | No | Gợi ý category; bắt buộc có khi "Đã mua" |
| `quantity` | Number | Yes | > 0 |
| `unit` | String | Yes | Đơn vị (dùng danh sách `_commonUnits` của item form) |
| `note` | String | No | Ghi chú ngắn (≤ 200 ký tự) |
| `source` | String | Yes | `manual` \| `voice` \| `suggestion` \| `ai_recipe` |
| `status` | String | Yes | `pending` \| `bought` |
| `addedBy` | String | Yes | uid người thêm (= `request.auth.uid`) |
| `boughtBy` | String | No | uid người tick (backend ghi) |
| `boughtAt` | Timestamp | No | backend ghi |
| `inventoryItemId` | String | No | item tạo ra khi "Đã mua" (backend ghi) |
| `createdAt` | Timestamp | Yes | |
| `updatedAt` | Timestamp | Yes | |

Thêm vào `FirestoreConstants.shoppingList = 'shopping_list'` và `Collections.SHOPPING_LIST = "shopping_list"`.
Thêm enum `ShoppingItemSource`, `ShoppingItemStatus` vào `app_enums.dart` (giống pattern `InventoryItemSource`).

Món `bought` giữ lại 30 ngày để hiện mục "Đã mua gần đây"; không cần xóa tự động (truy vấn chỉ lấy `pending` + `bought` có `boughtAt >= now-7d`).

### 3.2 Index (`firestore.indexes.json`)

```json
{ "collectionGroup": "shopping_list", "queryScope": "COLLECTION",
  "fields": [ {"fieldPath": "status", "order": "ASCENDING"},
              {"fieldPath": "createdAt", "order": "DESCENDING"} ] },
{ "collectionGroup": "shopping_list", "queryScope": "COLLECTION",
  "fields": [ {"fieldPath": "status", "order": "ASCENDING"},
              {"fieldPath": "boughtAt", "order": "DESCENDING"} ] }
```

Truy vấn lịch sử cho gợi ý dùng `inventory_items.where('purchaseDate', '>=', cutoff)` → index đơn field tự có.

### 3.3 Security Rules (thêm trong `match /households/{householdId}`)

```
match /shopping_list/{itemId} {
  function validShoppingFields(data) {
    return data.name is string && data.name.size() > 0 && data.name.size() <= 100
      && data.normalizedName is string
      && data.quantity is number && data.quantity > 0 && data.quantity <= 10000
      && data.unit is string && data.unit.size() > 0 && data.unit.size() <= 20
      && data.source in ['manual', 'voice', 'suggestion', 'ai_recipe']
      && (!('note' in data) || (data.note is string && data.note.size() <= 200));
  }
  allow read: if isHouseholdMember(householdId);
  allow create: if isHouseholdMember(householdId)
    && request.resource.data.status == 'pending'
    && request.resource.data.addedBy == request.auth.uid
    && validShoppingFields(request.resource.data);
  // Clients edit pending items only; "bought" is set by completeShoppingItems.
  allow update: if isHouseholdMember(householdId)
    && resource.data.status == 'pending'
    && request.resource.data.status == 'pending'
    && changedKeys().hasOnly(['name', 'normalizedName', 'foodId', 'categoryId',
                              'quantity', 'unit', 'note', 'updatedAt'])
    && validShoppingFields(request.resource.data);
  allow delete: if isHouseholdMember(householdId) && resource.data.status == 'pending';
}
```

(`isHouseholdMember` và `changedKeys` đã có trong `firestore.rules`.)

## 4. Backend (Cloud Functions)

Module mới **`functions/src/shopping/`**:

```
shopping/
├── callables/
│   ├── complete_shopping_items.ts
│   └── get_shopping_suggestions.ts
├── services/
│   ├── purchase_frequency.ts     # pure algorithm, no Firebase imports
│   └── shopping_service.ts       # Firestore reads/writes
└── index.ts                      # export * from callables; add to src/index.ts
```

### 4.1 Thuật toán "Hay mua" – `purchase_frequency.ts` (thuần, unit test)

Input:
```ts
export interface PurchaseRecord {   // one inventory_items document
  key: string;              // foodId ?? normalizedName
  name: string;
  quantity: number;
  unit: string;
  categoryId: string;
  foodId: string | null;
  purchaseDate: Date;
  status: "active" | "consumed" | "discarded";
  remainingPercentage: number;   // 0..100
}
export interface SuggestionInput {
  now: Date;
  records: PurchaseRecord[];          // purchaseDate >= now - 180 days
  pendingKeys: Set<string>;           // keys already pending in shopping_list
  timeZone?: string;                  // default "Asia/Ho_Chi_Minh"
}
```

Các bước (bắt buộc đúng thứ tự, hằng số đặt `export const` đầu file):

| Hằng số | Giá trị |
|---|---|
| `LOOKBACK_DAYS` | 180 |
| `MIN_PURCHASE_DAYS` | 3 (≥ 2 khoảng cách) |
| `DUE_RATIO` | 0.8 |
| `LOW_STOCK_RATIO` | 0.25 |
| `MAX_SUGGESTIONS` | 10 |

1. **Gom theo `key`** = `foodId ?? normalizedName` (đã chuẩn hóa ở backend bằng `normalizeFoodName`).
2. **Ngày mua**: đổi `purchaseDate` sang ngày lịch theo `Asia/Ho_Chi_Minh` (dùng `calendarDateKey` trong `inventory/services/expiry_planner.ts`); **nhiều batch cùng ngày = 1 lần mua**.
3. Bỏ key có `< MIN_PURCHASE_DAYS` ngày mua, hoặc nằm trong `pendingKeys`.
4. `intervals[]` = số ngày giữa hai ngày mua liên tiếp (đã sort tăng).
   `avgIntervalDays = max(1, median(intervals))` – dùng **median** để 1 lần mua lẻ không kéo lệch.
5. `lastPurchase` = ngày mua mới nhất, `daysSince` = số ngày lịch từ `lastPurchase` tới `now`.
6. Tồn kho: các record `status == "active"` của key.
   `stockLevel = Σ remainingPercentage / 100` (đơn vị "batch").
   `stockState = "out"` nếu không có active hoặc `stockLevel == 0`; `"low"` nếu `stockLevel < LOW_STOCK_RATIO`; ngược lại `"ok"`.
7. **Điều kiện gợi ý**: `daysSince >= DUE_RATIO * avgIntervalDays` **và** `stockState != "ok"`.
8. `score = (daysSince / avgIntervalDays) * (stockState == "out" ? 1 : 0.6) * Math.log2(1 + purchaseDays)`.
9. Số lượng gợi ý = **median quantity** của các lần mua; đơn vị = **unit xuất hiện nhiều nhất**; `name` = tên của lần mua gần nhất; `categoryId`, `foodId` lấy từ lần gần nhất.
10. Sort `score` giảm dần, cắt `MAX_SUGGESTIONS`.
11. `reason` (tiếng Việt, ghép cố định):
    `Bạn thường mua {name} mỗi ~{round(avgIntervalDays)} ngày, lần cuối {daysSince} ngày trước, {stockState=="out" ? "đã hết trong tủ" : "trong tủ còn ít"}.`

Output:
```ts
export interface ShoppingSuggestion {
  key: string; name: string; foodId: string | null; categoryId: string;
  quantity: number; unit: string;
  avgIntervalDays: number; daysSinceLastPurchase: number;
  purchaseCount: number; stockState: "out" | "low";
  score: number; reason: string;
}
export function buildShoppingSuggestions(input: SuggestionInput): ShoppingSuggestion[];
```

Unit test bắt buộc (`functions/test/purchase_frequency.test.js`):
- mua sữa ngày 1, 8, 15, hôm nay ngày 23, hết hàng → gợi ý, `avgIntervalDays = 7`, reason đúng chữ.
- cùng dữ liệu nhưng còn 1 batch 80% → **không** gợi ý.
- chỉ 2 ngày mua → không gợi ý.
- 3 batch cùng một ngày tính 1 lần mua.
- key đang `pending` trong danh sách → không gợi ý.
- 1 khoảng cách bất thường (60 ngày) không làm lệch median.
- sort theo score, tối đa 10.

### 4.2 `getShoppingSuggestions` (callable)

```ts
interface Payload { householdId: string }
// returns ApiResponse<{ suggestions: ShoppingSuggestion[] }>
```
1. `getAuthenticatedUser(request)`; validate `householdId` là string.
2. `verifyHouseholdAccess(uid, householdId)`.
3. `ShoppingService.loadPurchaseRecords(householdId, now)`: `inventory_items.where("purchaseDate", ">=", now-180d).limit(1000)`.
4. `ShoppingService.loadPendingKeys(householdId)`: `shopping_list.where("status","==","pending")`.
5. `buildShoppingSuggestions(...)` → trả về.

Không tốn quota AI, không ghi dữ liệu.

### 4.3 `completeShoppingItems` (callable) – "Đã mua"

```ts
interface CompleteItem {
  shoppingItemId: string;
  quantity: number;               // user can correct before confirming
  unit: string;
  categoryId: string;             // required to compute expiry
  storageLocationId: "fridge" | "freezer";
  foodId?: string | null;
  purchaseDate?: string;          // ISO, default now
}
interface Payload { householdId: string; items: CompleteItem[] }   // 1..50 items
// returns ApiResponse<{ addedCount: number; inventoryItemIds: string[] }>
```

Flow trong `ShoppingService.completeItems` – **một transaction duy nhất**:
1. Validate input (số lượng > 0, ≤ 50 item, `storageLocationId` hợp lệ, `categoryId` tồn tại trong `food_categories` – đọc trước transaction).
2. Tính `expirationDate` cho từng món **trước transaction** bằng `InventoryService.calculateExpirationDate(foodId, categoryId, storageLocationId, purchaseDate)` (đã có, theo `shelf_life_rules` → `defaultShelfLife` → fallback).
3. Trong transaction:
   - đọc từng `shopping_list/{id}`: phải tồn tại và `status == "pending"`, nếu không → `failed-precondition` "Món đã được người khác đánh dấu đã mua".
   - kiểm tra household membership + `foodLimit` + tăng `activeItemCount` – **tái sử dụng** logic của `InventoryService.addBatchInventoryItemsWithLimitCheck`.
     Refactor bắt buộc: tách phần ghi trong transaction thành
     `InventoryService.writeBatchInTransaction(tx, {uid, membershipId, householdId, items})` trả về `itemIds`,
     để `addBatchInventoryItemsWithLimitCheck` và `completeItems` dùng chung (không copy code).
   - item inventory mới: `source: "manual"` (đề không có source "shopping"; giữ enum hiện có), `name` lấy từ shopping item.
   - update shopping item: `status: "bought"`, `boughtBy: uid`, `boughtAt`, `inventoryItemId`, `updatedAt`.
4. Trả `inventoryItemIds`.

Lỗi `foodLimit` → `resource-exhausted` với message đã có của InventoryService; client hiện dialog nâng cấp (giống item form).

## 5. Flutter

### 5.1 Cấu trúc file (feature mới `lib/features/shopping/`)

```
shopping/
├── domain/
│   ├── entities/shopping_item.dart
│   ├── entities/shopping_suggestion.dart
│   ├── repositories/shopping_repository.dart
│   └── usecases/
│       ├── watch_shopping_list.dart
│       ├── add_shopping_item.dart          # merge rule (5.3)
│       ├── update_shopping_item.dart
│       ├── delete_shopping_item.dart
│       ├── complete_shopping_items.dart
│       ├── get_shopping_suggestions.dart
│       └── parse_voice_shopping_text.dart  # pure parser (5.4)
├── data/
│   ├── models/shopping_item_model.dart
│   ├── models/shopping_suggestion_model.dart
│   ├── datasources/shopping_remote_datasource.dart
│   └── repositories/shopping_repository_impl.dart
└── presentation/
    ├── pages/shopping_list_page.dart
    ├── providers/shopping_list_provider.dart
    ├── providers/shopping_suggestions_provider.dart
    └── widgets/
        ├── shopping_item_tile.dart
        ├── frequent_suggestion_card.dart
        ├── add_shopping_item_sheet.dart
        ├── voice_add_sheet.dart
        └── complete_items_sheet.dart
```

Route mới: `AppRouteNames.shoppingList = '/shopping-list'` (subpage, `SubpageLayout`).
Điểm vào: thêm card "Danh sách đi chợ" trên Home (section header có "Xem tất cả") và mục trong Profile menu. Không thay đổi 4 tab chính.

### 5.2 Providers (Riverpod)

- `shoppingListStreamProvider` – `StreamProvider.autoDispose<List<ShoppingItem>>`, theo `currentUserProvider.activeHouseholdId`; trả pending (sort `createdAt desc`) + bought 7 ngày gần nhất.
- `shoppingSuggestionsProvider` – `FutureProvider.autoDispose<List<ShoppingSuggestion>>`, gọi callable; refresh bằng `ref.invalidate` (pull-to-refresh) và sau khi "Đã mua".
- `shoppingListControllerProvider` – `AsyncNotifier` cho add/update/delete/complete; mọi lỗi map sang `Failure` → `ToastHelper.show(..., isError: true)`.

### 5.3 Quy tắc thêm món (use case `AddShoppingItem`)

- `name` trim, 1..100 ký tự; `quantity > 0`; `unit` bắt buộc.
- **Gộp trùng**: nếu đã có item `pending` cùng `normalizedName` **và** cùng `unit` → tăng `quantity` của item đó (update), không tạo mới. Khác unit → tạo item riêng.
- Chạy trong Firestore transaction ở datasource (đọc pending cùng normalizedName → update hoặc create) để 2 người thêm cùng lúc không tạo trùng.
- Từ gợi ý: `source: suggestion`, điền sẵn quantity/unit/categoryId/foodId từ suggestion.
- Autocomplete tên: tái dùng `searchFoodSuggestions` của inventory (đã có) để lấy `foodId`, `categoryId`, `defaultUnit`.

### 5.4 Parser giọng nói (use case `ParseVoiceShoppingText`, Dart thuần)

Mục tiêu: "mua 2 hộp sữa, 1 kg thịt heo và 6 quả trứng" → 3 dòng nháp.
1. Lowercase giữ dấu; tách đoạn bằng `,` `;` ` và ` ` với ` ` rồi `.`.
2. Bỏ tiền tố: `mua`, `thêm`, `cần`, `nhớ mua`.
3. Mỗi đoạn khớp regex `^(\d+(?:[.,]\d+)?|một|hai|ba|bốn|năm|sáu|bảy|tám|chín|mười|nửa)\s*(<unit>)?\s+(.+)$`
   với `<unit>` = danh sách đơn vị của item form (`quả|hộp|kg|g|miếng|lon|chai|gói|cây|túi`) + `lốc|vỉ|bó|lạng|lít|ml`.
   `lạng` = 0,1 kg (đổi sang `kg`), số chữ → số. Không khớp → `quantity 1`, `unit` = `defaultUnit` từ autocomplete hoặc `quả`, `name` = cả đoạn.
4. Kết quả **luôn** hiện trong `voice_add_sheet` dạng danh sách sửa được (tên/số lượng/đơn vị, xóa dòng). Chỉ lưu khi bấm "Thêm vào danh sách"; mỗi dòng đi qua `AddShoppingItem` với `source: voice`.

Unit test: số, số chữ, "nửa kg", "lạng", không có đơn vị, nhiều đoạn, chuỗi rỗng.

### 5.5 Flow "Đã mua"

1. User tick checkbox ở 1 hoặc nhiều item → nút "Đã mua (n)" hiện ở `AppBottomBar`.
2. Mở `complete_items_sheet` (BottomSheetHelper): mỗi món có **ngăn (Ngăn mát/Ngăn đông)**, **category** (bắt buộc nếu item chưa có), số lượng/đơn vị sửa được, ngày mua (mặc định hôm nay).
3. Bấm "Thêm vào tủ" → `completeShoppingItems`. Loading trên nút; thành công → toast "Đã thêm n món vào tủ lạnh", invalidate suggestions. Lỗi `resource-exhausted` → dialog "Đã đạt giới hạn thực phẩm" + nút "Nâng cấp" (route membership).
4. Hạn dùng **không** cho nhập ở sheet này (backend tính); user muốn sửa thì vào item form sau.

### 5.6 UI màn `ShoppingListPage`

- Header `AppHeader` "Danh sách đi chợ", action icon `LucideIcons.map` → "Đi chợ" (PLAN 03).
- Section 1 "Gợi ý hay mua" (ẩn nếu rỗng): list ngang `FrequentSuggestionCard` (tên, số lượng gợi ý, reason 2 dòng, nút "+ Thêm"). Loading = `AppShimmer`, lỗi = dòng nhỏ có "Thử lại" (không chặn danh sách).
- Section 2 "Cần mua" (pending): `ShoppingItemTile` – checkbox, tên, `quantity unit`, người thêm (tên thành viên nếu có PLAN 05), swipe trái xóa (`DialogHelper.showDeleteDialog`), tap → sửa.
- Section 3 "Đã mua gần đây" (thu gọn mặc định).
- `AppFloatingActionButton` "+": sheet chọn "Nhập tay" / "Nói" (mic).
- Empty state: `EmptyStateWidget` "Danh sách trống" + gợi ý dùng mic.
- Responsive: ScreenUtil, `SubpageLayout` (maxWidth 600.w), sheet maxWidth 520.w; form có `GestureDetector` unfocus + `keyboardDismissBehavior.onDrag`.

## 6. Edge cases bắt buộc xử lý

| Case | Xử lý |
|---|---|
| Hai thành viên cùng tick một món | Transaction thấy `status != pending` → lỗi `failed-precondition`, client toast + list tự cập nhật |
| Món chưa có category khi "Đã mua" | Sheet bắt buộc chọn category trước khi enable nút |
| Free user đạt `foodLimit` | Không món nào được thêm (transaction rollback), shopping item vẫn `pending` |
| Household chưa có lịch sử | Suggestions rỗng → ẩn section |
| Mất mạng | Firestore offline cache vẫn hiển thị list; callable lỗi → toast "Kiểm tra kết nối" |
| User rời household (PLAN 05) | Stream đổi theo `activeHouseholdId` mới |

## 7. Test

- Functions: `purchase_frequency.test.js` (mục 4.1), test `validate` input của `completeShoppingItems` (tách validator thuần).
- Flutter unit: `ParseVoiceShoppingText`, `AddShoppingItem` (merge rule với fake repository), `ShoppingItemModel` serialize.
- Flutter widget: `ShoppingListPage` hiển thị empty state; tick 2 item hiện "Đã mua (2)"; `FrequentSuggestionCard` hiện reason.
- Rules (emulator thủ công hoặc `@firebase/rules-unit-testing`): client không set được `status: 'bought'`, non-member không đọc được.

## 8. Cập nhật tài liệu (cùng PR)

- DATABASE.md: thêm mục `households/{householdId}/shopping_list`, cây cấu trúc §2, quan hệ §18.
- FUNCTIONS_GUIDE.md: module `shopping/` + 2 callable trong bảng.
- `firestore.rules`, `firestore.indexes.json` như mục 3.
- PROJECT_STRUCTURE.md: feature `shopping` (12 feature).

## 9. Definition of Done

- [ ] Thêm tay / giọng nói / từ gợi ý đều qua bước xác nhận và ghi đúng `source`.
- [ ] 2 thiết bị cùng household thấy thay đổi realtime.
- [ ] "Đã mua" tạo inventory item có `expirationDate` khớp shelf-life rule (so với item form cùng món).
- [ ] `activeItemCount` tăng đúng; Free vượt `foodLimit` bị chặn.
- [ ] Gợi ý có reason đúng format, không gợi ý món đang có đủ hoặc đang pending.
- [ ] Analyzer/test/lint pass; chạy trên APK release máy thật (mic tiếng Việt).

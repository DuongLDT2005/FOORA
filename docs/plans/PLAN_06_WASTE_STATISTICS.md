# PLAN 06 – Thống kê lãng phí (Waste statistics)

> Chức năng bổ sung trong `PRM393_Project.docx`: *"charts of consumed vs. discarded items per month, the waste rate,
> and the foods thrown away most often."*
> Độc lập; dùng dữ liệu `inventory_items` đã có (`status: consumed | discarded`).

## 1. Công nghệ

| Phần | Công nghệ | Phiên bản |
|---|---|---|
| Biểu đồ | `fl_chart` (MIT, Android + Web) | `^1.2.0` |
| Dữ liệu | Firestore query `inventory_items` (đã có) | — |
| Tính toán | Use case Dart thuần trong domain (unit test) | — |

Không cần Cloud Function: chỉ đọc dữ liệu household mà member đã được phép đọc, khối lượng nhỏ (≤ 2.000 doc).

`pubspec.yaml`: `fl_chart: ^1.2.0`.

## 2. Vấn đề dữ liệu cần sửa trước (bắt buộc để số liệu chính xác)

Hiện **không có field ghi thời điểm đổi trạng thái**. `updatedAt` bị ghi đè khi sửa bất kỳ field nào → thống kê theo tháng sẽ sai.

Thêm field `statusChangedAt: Timestamp` vào `inventory_items`:
- Tạo item (`addInventoryItem`, `batchAddInventoryItems`, `completeShoppingItems`): `statusChangedAt = createdAt`.
- Mọi chỗ đổi `status` sang `consumed`/`discarded` ghi `statusChangedAt: serverTimestamp()`:
  - Flutter `InventoryRemoteDataSource.batchUpdateInventoryStatus` (swipe, xóa hàng loạt hết hạn);
  - Flutter `updateInventoryItem` **chỉ khi** status thay đổi (so sánh với item gốc trong repository impl);
  - Backend `applyAiActions` (PLAN 04).
- Rules `inventory_items` update: thêm `statusChangedAt` vào `hasOnly([...])` và ràng buộc
  `(!changedKeys().hasAny(['statusChangedAt']) || request.resource.data.statusChangedAt == request.time)`;
  đồng thời nếu `status` đổi thì **bắt buộc** `statusChangedAt == request.time`.
- **Backfill 1 lần** cho dữ liệu cũ: script `functions/src/scripts/backfill_status_changed_at.ts`
  (Admin SDK, chạy `npm run build && node lib/scripts/backfill_status_changed_at.js [--prod]`):
  với mọi item `consumed|discarded` thiếu field → `statusChangedAt = updatedAt`; item `active` → `= createdAt`. Batch 400 doc/lần.
  Ghi vào báo cáo: số liệu trước ngày backfill là gần đúng (dựa trên `updatedAt`).

Index (`firestore.indexes.json`):
```json
{ "collectionGroup": "inventory_items", "queryScope": "COLLECTION",
  "fields": [ {"fieldPath": "status", "order": "ASCENDING"},
              {"fieldPath": "statusChangedAt", "order": "ASCENDING"} ] }
```

## 3. Định nghĩa số liệu (ghi vào báo cáo đúng như này)

- Đơn vị đếm: **số lô thực phẩm** (mỗi `inventory_items` doc). Không cộng `quantity` vì đơn vị khác nhau (quả, kg, hộp).
- Một lô thuộc tháng = tháng (giờ VN `Asia/Ho_Chi_Minh`) của `statusChangedAt`.
- `consumed` = đã dùng; `discarded` = vứt bỏ (hỏng/hết hạn).
- **Tỷ lệ lãng phí** = `discarded / (consumed + discarded)` × 100, làm tròn 1 chữ số; mẫu số 0 → hiển thị "—".
- **Vứt khi đã quá hạn**: lô `discarded` có `statusChangedAt > expirationDate` (thông tin phụ dưới tiêu đề top món).
- **Món bị vứt nhiều nhất**: gom theo `foodId ?? normalizedName`, đếm lô `discarded` trong kỳ, top 5, tên hiển thị = tên lô gần nhất, kèm `%` trên tổng lô bị vứt.
- Kỳ chọn: 3 / 6 / 12 tháng gần nhất (mặc định 6), **gồm tháng hiện tại**.

## 4. Flutter

### 4.1 File (feature mới `lib/features/statistics/`)

```
statistics/
├── domain/
│   ├── entities/waste_statistics.dart        # MonthlyWaste, TopWastedFood, totals
│   ├── entities/status_change_record.dart    # key, name, status, changedAt, expirationDate
│   ├── repositories/statistics_repository.dart
│   └── usecases/
│       ├── get_status_change_records.dart
│       └── compute_waste_statistics.dart     # pure
├── data/
│   ├── datasources/statistics_remote_datasource.dart
│   ├── models/status_change_record_model.dart
│   └── repositories/statistics_repository_impl.dart
└── presentation/
    ├── pages/waste_statistics_page.dart
    ├── providers/waste_statistics_provider.dart
    └── widgets/{period_selector.dart, waste_summary_cards.dart,
                 monthly_waste_bar_chart.dart, waste_ratio_pie_chart.dart, top_wasted_foods_list.dart}
```
Route: `AppRouteNames.wasteStatistics = '/profile/waste-statistics'`. Điểm vào: Profile menu "Thống kê lãng phí" + chạm vào `HomeStatsBoard`.

### 4.2 Datasource

```dart
firestore
  .collection(FirestoreConstants.households).doc(householdId)
  .collection(FirestoreConstants.inventoryItems)
  .where('status', whereIn: ['consumed', 'discarded'])
  .where('statusChangedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fromUtc))
  .orderBy('statusChangedAt')
  .limit(2000)
  .get();
```
`fromUtc` = 00:00 ngày 1 của tháng đầu kỳ theo giờ VN, đổi sang UTC (VN = UTC+7, không có DST → `DateTime.utc(y, m, 1).subtract(const Duration(hours: 7))`).
Dùng `get()` (không stream) – thống kê không cần realtime; pull-to-refresh để tải lại. Đạt 2000 doc → hiển thị ghi chú "Chỉ tính 2000 lô gần nhất".

### 4.3 Use case `ComputeWasteStatistics` (thuần)

```dart
WasteStatistics call({
  required List<StatusChangeRecord> records,
  required DateTime nowVn,          // already shifted to Vietnam time
  required int months,              // 3 | 6 | 12
});
```
Trả về:
- `monthly`: đủ `months` phần tử (tháng không có dữ liệu = 0), sort cũ → mới, nhãn `MM/yy`;
- `totalConsumed`, `totalDiscarded`, `wasteRatePercent` (null nếu mẫu số 0);
- `discardedAfterExpiry` (số lô);
- `topWasted` (≤ 5): `{key, name, count, percentOfDiscarded}`, sort count giảm dần, hòa thì theo tên.
- So sánh với kỳ trước? **Không** (đề không yêu cầu).

Unit test bắt buộc: tháng trống được fill 0; biên tháng theo giờ VN (23:30 UTC ngày cuối tháng = tháng sau ở VN); rate làm tròn; top 5 gom theo foodId và normalizedName; không có dữ liệu → rate null.

### 4.4 UI `WasteStatisticsPage`

- `SubpageLayout` + `AppHeader` "Thống kê lãng phí".
- `PeriodSelector`: `AppSegmentedControl` 3 / 6 / 12 tháng.
- `WasteSummaryCards`: 3 `StatisticCard` – Đã dùng (good), Đã vứt (expired), Tỷ lệ lãng phí (warning khi > 20%).
- `MonthlyWasteBarChart` (fl_chart `BarChart`): mỗi tháng 2 thanh – consumed `AppColors.emerald500`, discarded `AppColors.red500`;
  trục X nhãn `MM/yy` (`SideTitles`, font `.sp`), trục Y số nguyên; `BarTouchData` tooltip "Đã dùng: 12 lô".
  Chiều cao `220.h`; 12 tháng → `SingleChildScrollView(scrollDirection: Axis.horizontal)` với width tối thiểu `48.w * months`.
- `WasteRatioPieChart` (`PieChart`): 2 phần consumed/discarded, nhãn % ở giữa; ẩn khi tổng = 0.
- `TopWastedFoodsList`: hạng, `FoodImageAvatar` (đã có), tên, "5 lần · 31%", thanh `LinearProgressIndicator` màu `AppColors.red500`.
- Trạng thái: loading `AppShimmer`; lỗi `ErrorStateWidget` + Thử lại; trống `EmptyStateWidget` "Chưa có dữ liệu trong kỳ này".
- Legend dưới chart (chấm màu + chữ) – không dùng màu làm thông tin duy nhất.

### 4.5 Provider

`wasteStatisticsProvider = FutureProvider.autoDispose.family<WasteStatistics, int>((ref, months) ...)`:
đọc `activeHouseholdId` → `GetStatusChangeRecords` → `ComputeWasteStatistics`. Period đổi → family key đổi (cache theo kỳ).

## 5. Test

- Unit: `ComputeWasteStatistics` (mục 4.3), model parse `statusChangedAt` thiếu (dùng `updatedAt` fallback trong model để không crash nếu chưa backfill).
- Widget: trang hiển thị 3 summary card với fake provider; trạng thái trống; đổi segment gọi provider với key mới.
- Rules: client đổi `status` mà không set `statusChangedAt` → bị từ chối.
- Thủ công: swipe vứt 2 món, dùng 3 món → biểu đồ tháng hiện tại 3/2, tỷ lệ 40%.

## 6. Cập nhật tài liệu

- DATABASE.md §9: field `statusChangedAt` + quy tắc ghi; §2 cây không đổi.
- `firestore.rules`, `firestore.indexes.json`.
- Báo cáo: định nghĩa số liệu mục 3, công nghệ `fl_chart`.

## 7. Definition of Done

- [ ] Mọi đường đổi status (swipe, xóa hàng loạt, item form, AI) ghi `statusChangedAt`.
- [ ] Backfill chạy xong trên emulator và production (Tech Lead).
- [ ] Biểu đồ theo tháng, tỷ lệ lãng phí, top 5 món bị vứt đúng với dữ liệu kiểm tra tay.
- [ ] Hiển thị tốt trên APK release (điện thoại) và màn tablet (maxWidth 600.w).

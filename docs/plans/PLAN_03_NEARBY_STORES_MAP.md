# PLAN 03 – Bản đồ siêu thị / chợ gần đây

> Chức năng 8 trong `PRM393_Project.docx`: *"OpenStreetMap map showing the user's location and nearby supermarkets
> and markets, with name, distance and directions. It opens directly from the shopping list ('Go shopping')."*
> Phụ thuộc: PLAN 01 (nút "Đi chợ"). Có thể làm độc lập nếu tạm mở từ Home.

## 1. Công nghệ (đã kiểm tra 2026-10-18)

| Phần | Công nghệ | Phiên bản | Vì sao chọn |
|---|---|---|---|
| Hiển thị bản đồ | `flutter_map` | `^8.3.2` | Free, không cần API key, chạy Android/Web; có sẵn cache tile (từ 8.2.0) đáp ứng tile policy |
| Toạ độ | `latlong2` | `^0.9.1` | Dependency bắt buộc của flutter_map (`>=0.9.1 <0.11.0`) |
| Tile | OSM `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | — | Free; app native được phép nếu có User-Agent + attribution + không tải trước |
| Vị trí người dùng | `geolocator` | `^14.1.1` | Plugin chuẩn, có `distanceBetween` (mét) |
| Dữ liệu cửa hàng | Overpass API (OSM) qua Cloud Function `getNearbyStores` | — | Free; gọi từ server để dùng chung cache, kiểm soát User-Agent và tổng lượng request |
| Chỉ đường | `url_launcher ^6.3.3` + Google Maps URLs | — | Không cần API key, mở app Google Maps (có route thật, chính xác), không có thì mở trình duyệt |

**Không dùng** Google Maps SDK (cần API key + billing), Mapbox (giới hạn/token), OSRM demo server (không cho production).

### 1.1 Cài đặt

`pubspec.yaml`:
```yaml
flutter_map: ^8.3.2
latlong2: ^0.9.1
geolocator: ^14.1.1
url_launcher: ^6.3.3
```

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- inside the existing <queries> -->
<intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/>
</intent>
```
- **Không** thêm `ACCESS_BACKGROUND_LOCATION`.
- `geolocator` yêu cầu `compileSdk 35`; `flutter.compileSdkVersion` của Flutter 3.47 đã ≥ 35 – kiểm tra bằng `flutter build apk` nếu báo lỗi thì đặt `compileSdk = 36` trong `android/app/build.gradle.kts`.
- `android/gradle.properties` phải có `android.useAndroidX=true` (đã có với project Flutter mới).

## 2. Quy định bắt buộc (vi phạm có thể bị chặn không báo trước)

**OSM tile policy** (operations.osmfoundation.org/policies/tiles):
1. Dùng HTTPS URL ở trên, không dùng `a/b/c.tile...`.
2. `TileLayer(userAgentPackageName: 'com.foora.foora')` – User-Agent riêng, ổn định. Không đổi tên sản phẩm theo version.
3. Attribution "© OpenStreetMap contributors" **luôn nhìn thấy** (góc dưới phải), không che bởi bottom sheet → đặt `RichAttributionWidget` và chừa padding bằng chiều cao sheet.
4. Không tải trước / không "tải bản đồ offline" / không bulk download. Chỉ tải tile user đang xem.
5. Giữ cache mặc định của flutter_map (tôn trọng Cache-Control). Không thêm header `no-cache`.
6. Giới hạn zoom `minZoom: 3, maxZoom: 19`.

**Overpass policy:** < ~10.000 request/ngày và < 1 GB/ngày **tổng cho cả app**, gặp 429/504 thì chờ ≥ 30 s, gửi User-Agent định danh app.
→ Chỉ gọi từ Cloud Function, cache theo ô lưới 24 giờ (mục 4).

## 3. Phạm vi kết quả "chính xác"

- Vị trí user: `LocationAccuracy.high`, timeout 15 s; nếu có last known position < 2 phút thì dùng ngay rồi cập nhật.
- Danh sách cửa hàng lấy từ OSM, các tag:
  - `shop=supermarket` (WinMart, Co.opmart, Bách Hóa Xanh, Lotte Mart, Aeon…),
  - `shop=convenience` (WinMart+, Circle K, GS25…),
  - `shop=greengrocer`, `shop=butcher`,
  - `amenity=marketplace` (chợ truyền thống).
- Khoảng cách hiển thị = **đường chim bay** bằng `Geolocator.distanceBetween`, ghi rõ "≈ 1,2 km (đường chim bay)". Khoảng cách/đường đi thực tế do Google Maps tính khi bấm "Chỉ đường" → không tự vẽ route (tránh sai số và dịch vụ trả phí).
- Lưu ý ghi vào báo cáo: dữ liệu OSM ở Việt Nam có thể thiếu một số cửa hàng nhỏ; app hiển thị "Dữ liệu © OpenStreetMap" và nút "Mở tìm kiếm trên Google Maps" (`https://www.google.com/maps/search/?api=1&query=siêu+thị`) làm phương án dự phòng khi danh sách trống.

## 4. Backend – callable `getNearbyStores`

### 4.1 File

```
functions/src/places/
├── callables/get_nearby_stores.ts
├── services/overpass_client.ts     # HTTP + retry, injectable fetch for tests
├── services/places_service.ts      # cache + mapping
├── services/overpass_query.ts      # pure: build query, parse elements
└── index.ts
```
Collection server-only mới: `place_cache/{cellId}` (Rules: `allow read, write: if false`).

### 4.2 Input / output

```ts
interface Payload { lat: number; lng: number; radiusMeters?: number } // radius 500..5000, default 3000
interface NearbyStore {
  id: string;            // "node/123", "way/456"
  name: string;          // tags.name ?? tags.brand ?? "Chợ"/"Siêu thị" theo loại
  kind: "supermarket" | "convenience" | "greengrocer" | "butcher" | "marketplace";
  lat: number; lng: number;
  address: string | null;   // ghép addr:housenumber + addr:street + addr:district (nếu có)
  openingHours: string | null;  // tags.opening_hours, hiển thị nguyên văn
}
// ApiResponse<{ stores: NearbyStore[]; cached: boolean; source: "openstreetmap" }>
```

Validate: lat ∈ [-90, 90], lng ∈ [-180, 180], `Number.isFinite`, radius clamp. Yêu cầu đăng nhập (`getAuthenticatedUser`) để chống lạm dụng.

### 4.3 Cache

- `cellId` = làm tròn toạ độ 2 chữ số thập phân (~1,1 km) + radius: `"${lat.toFixed(2)}_${lng.toFixed(2)}_${radius}"`.
- Truy vấn Overpass với **tâm ô** (không phải toạ độ chính xác của user) → nhiều user gần nhau dùng chung cache, và không gửi vị trí chính xác của user ra bên thứ ba.
- Bán kính truy vấn thực = `radius + 800` m để bù việc làm tròn tâm; client lọc lại theo khoảng cách thật tới user.
- TTL 24 h (`fetchedAt`). Hết hạn → gọi lại; Overpass lỗi mà còn cache cũ → trả cache cũ, `cached: true`.
- Giới hạn doc: tối đa 200 cửa hàng/ô.

### 4.4 Query Overpass (pure builder)

```
[out:json][timeout:25];
(
  nwr["shop"~"^(supermarket|convenience|greengrocer|butcher)$"](around:{R},{LAT},{LNG});
  nwr["amenity"="marketplace"](around:{R},{LAT},{LNG});
);
out center tags 200;
```
- `nwr` + `out center` để lấy toạ độ cả cho way/relation (tòa nhà siêu thị vẽ dạng polygon).
- Parse: node dùng `lat/lon`, way/relation dùng `center.lat/center.lon`; bỏ phần tử không có toạ độ; bỏ `shop=convenience` không có `name`/`brand` (ít giá trị).

### 4.5 HTTP client

- `POST https://overpass-api.de/api/interpreter`, body `data=<urlencoded query>`, header
  `User-Agent: FOORA/1.0 (com.foora.foora; contact: foora.team@gmail.com)`, `Content-Type: application/x-www-form-urlencoded`.
- Timeout 30 s (`AbortSignal.timeout`).
- 429/504: **không retry dồn dập** – thử lại 1 lần sau 2 s; vẫn lỗi → trả cache cũ hoặc `HttpsError("unavailable", "Máy chủ bản đồ đang bận, thử lại sau ít phút")`.
- Endpoint đặt trong `defineString("OVERPASS_URL", {default: "https://overpass-api.de/api/interpreter"})` để đổi instance mà không sửa code.
- Function options: `{region: REGION, timeoutSeconds: 40, maxInstances: 5}`.

Unit test (`functions/test/overpass_query.test.js`): build query đúng radius/tâm; parse node/way; bỏ phần tử thiếu toạ độ; đặt tên mặc định; build cellId.

## 5. Flutter

### 5.1 File (feature mới `lib/features/places/`)

```
places/
├── domain/entities/nearby_store.dart
├── domain/entities/user_location.dart
├── domain/repositories/places_repository.dart
├── domain/usecases/get_nearby_stores.dart        # sort by real distance, filter by radius
├── domain/usecases/get_current_location.dart
├── data/datasources/location_datasource.dart     # geolocator wrapper
├── data/datasources/places_remote_datasource.dart # callable getNearbyStores
├── data/models/nearby_store_model.dart
├── data/repositories/places_repository_impl.dart
└── presentation/
    ├── pages/nearby_stores_page.dart
    ├── providers/nearby_stores_provider.dart
    └── widgets/{store_marker.dart, store_list_sheet.dart, store_detail_card.dart, location_permission_view.dart}
```
Route: `AppRouteNames.nearbyStores = '/shopping-list/nearby-stores'`. Mở từ icon "Đi chợ" ở `ShoppingListPage` (PLAN 01).

### 5.2 Luồng quyền vị trí (location_datasource)

```dart
Future<UserLocation> getCurrentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(LocationErrorCode.serviceDisabled);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException(LocationErrorCode.denied);
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(LocationErrorCode.deniedForever);
  }
  final last = await Geolocator.getLastKnownPosition();
  if (last != null && DateTime.now().difference(last.timestamp) < const Duration(minutes: 2)) {
    return UserLocation(last.latitude, last.longitude, last.accuracy);
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  return UserLocation(pos.latitude, pos.longitude, pos.accuracy);
}
```
`LocationException` thêm vào `core/errors/exceptions.dart`, map sang `LocationFailure` trong repository.
UI (`location_permission_view`):
- `serviceDisabled` → nút "Bật định vị" → `Geolocator.openLocationSettings()`.
- `denied` → giải thích + nút "Cho phép" (gọi lại).
- `deniedForever` → nút "Mở cài đặt ứng dụng" → `Geolocator.openAppSettings()`.
- Timeout → "Không lấy được vị trí, thử lại" + vẫn cho tìm theo Google Maps.

### 5.3 Use case `GetNearbyStores`

1. Gọi repository với `lat/lng/radius` (mặc định 3000 m).
2. Tính `distanceMeters` = `Geolocator.distanceBetween(user, store)` – **đặt trong data layer** (repository impl) để domain không phụ thuộc plugin; domain nhận `distanceMeters` sẵn.
3. Lọc `distance <= radius`, sort tăng dần, giữ 50 cửa hàng gần nhất.
4. Nếu < 5 kết quả và radius < 5000 → tự gọi lại với 5000 m **một lần**.

### 5.4 Màn hình `NearbyStoresPage`

```dart
FlutterMap(
  options: MapOptions(initialCenter: userLatLng, initialZoom: 15, minZoom: 3, maxZoom: 19),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.foora.foora',
    ),
    MarkerLayer(markers: [userMarker, ...storeMarkers]),
    RichAttributionWidget(
      attributions: [
        TextSourceAttribution('OpenStreetMap contributors',
          onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright'))),
      ],
    ),
  ],
)
```
- Marker user: chấm xanh `AppColors.blue500` + vòng độ chính xác (`CircleLayer` bán kính `accuracy` m, `useRadiusInMeter: true`).
- Marker cửa hàng: icon theo `kind` (`LucideIcons.store`, `shoppingBasket`, `carrot`, `beef`, `tent` cho chợ), màu `AppColors`.
- Bottom sheet kéo được (`DraggableScrollableSheet`, maxWidth 520.w): danh sách tên, loại, "≈ 850 m", địa chỉ, giờ mở cửa (nếu có). Tap → map `move` tới cửa hàng + `StoreDetailCard`.
- `StoreDetailCard` (maxWidth 440.w): tên, khoảng cách, địa chỉ, nút **"Chỉ đường"**:
  ```dart
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${store.lat},${store.lng}',
    'travelmode': 'driving', // xe máy: Google không có mode riêng ở URL; dùng driving
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
  ```
- Filter chips: Tất cả / Siêu thị / Cửa hàng tiện lợi / Chợ.
- Nút "Vị trí của tôi" (FAB nhỏ) recenter. Nút "Tìm lại khu vực này" khi user kéo map xa > 1 km (gọi với tâm map).
- Loading: map hiện ngay ở vị trí user, sheet hiện `AppShimmer`. Lỗi backend: `ErrorStateWidget` trong sheet + "Thử lại" + "Tìm trên Google Maps".
- Empty: "Không tìm thấy cửa hàng trong 5 km" + nút Google Maps search.
- Web admin không dùng màn này; trên web `userAgentPackageName` bị trình duyệt bỏ qua (OK).

## 6. Test

- Functions: `overpass_query.test.js`, test `places_service` với fake fetch (cache hit, cache stale + Overpass lỗi, 429).
- Flutter unit: `GetNearbyStores` sort/lọc/mở rộng radius với fake repository; mapping `LocationException` → `LocationFailure`.
- Flutter widget: `NearbyStoresPage` hiển thị `location_permission_view` khi repository trả `denied`; bottom sheet hiển thị "≈ 850 m".
- Thủ công trên **máy thật** (APK release): bật/tắt GPS, từ chối quyền 2 lần (deniedForever), bấm "Chỉ đường" mở Google Maps đúng điểm.

## 7. Cập nhật tài liệu

- DATABASE.md: collection server-only `place_cache/{cellId}` (fields: `stores[]`, `fetchedAt`, `radius`, `center`).
- FUNCTIONS_GUIDE.md: module `places/`, callable `getNearbyStores`, param `OVERPASS_URL`.
- `firestore.rules`: `match /place_cache/{id} { allow read, write: if false; }`.
- Báo cáo (mục "new technologies"): flutter_map, OSM tile policy, Overpass, geolocator.

## 8. Definition of Done

- [ ] Mở từ shopping list, xin quyền đúng luồng 3 trạng thái.
- [ ] Hiển thị vị trí user + cửa hàng có tên, khoảng cách (chim bay), sort gần → xa.
- [ ] "Chỉ đường" mở Google Maps app đúng toạ độ.
- [ ] Attribution OSM luôn nhìn thấy; User-Agent `com.foora.foora` (kiểm tra bằng log).
- [ ] Gọi lại cùng khu vực trong 24 h không gọi Overpass (log `cached: true`).
- [ ] Chạy trên APK release máy thật.

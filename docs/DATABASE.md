# FOORA – Database Design

## 1. Database

- Database: Cloud Firestore
- Database Type: NoSQL
- Authentication: Firebase Authentication
- File Storage: Firebase Storage

---

## 2. Database Structure

```text
Firestore
│
├── users
│   └── {userId}
│       ├── subscriptions
│       │   └── {subscriptionId}
│       │
│       ├── receipts
│       │   └── {receiptId}
│       │       └── items
│       │           └── {receiptItemId}
│       │
│       ├── notifications
│       │   └── {notificationId}
│       │
│       ├── devices
│       │   └── {deviceId}
│       │
│       ├── ai_usage
│       │   └── current
│       │
│       └── payments
│           └── {paymentId}
│
├── households
│   └── {householdId}
│       └── inventory_items
│           └── {inventoryItemId}
│
├── memberships
│   └── {membershipId}
│
├── foods
│   └── {foodId}
│
├── food_categories
│   └── {categoryId}
│
├── storage_locations
│   └── {locationId}
│
└── shelf_life_rules
    └── {ruleId}
```

---

# 3. Collection: users

**Path**

```text
users/{userId}
```

| Field               | Type      | Required | Description                      |
| ------------------- | --------- | -------: | -------------------------------- |
| `fullName`          | String    |      Yes | Full name                        |
| `email`             | String    |      Yes | User email                       |
| `role`              | String    |      Yes | `member` or `admin`              |
| `membershipId`      | String    |      Yes | Current membership ID            |
| `activeHouseholdId` | String    |      Yes | Reference to active household ID |
| `isActive`          | Boolean   |      Yes | true or false                    |
| `createdAt`         | Timestamp |      Yes | Creation time                    |
| `updatedAt`         | Timestamp |      Yes | Last update time                 |

Authentication credentials are managed by Firebase Authentication.

Do not store:

```text
password
passwordHash
authenticationSecret
```

inside this document.

> **Security Rules & Access Control**:
>
> - `fullName`, `updatedAt`, `avatarUrl`: The authenticated document owner (`isOwner`) is allowed to update these profile fields directly.
> - `role`, `membershipId`, `isActive`, `activeHouseholdId`: System-protected fields strictly guarded by Security Rules; clients cannot mutate them (managed exclusively via Cloud Functions / Admin SDK).

---

# 4. Collection: memberships

**Path**

```text
memberships/{membershipId}
```

| Field              | Type                 | Required | Description                                       |
| ------------------ | -------------------- | -------: | ------------------------------------------------- |
| `membershipId`     | String (Document ID) |      Yes | Unique membership identifier (free, premium)      |
| `name`             | String               |      Yes | Membership name                                   |
| `price`            | Number               |      Yes | Membership price                                  |
| `currency`         | String               |      Yes | Currency code                                     |
| `durationDays`     | Number               |      Yes | Membership duration                               |
| `foodLimit`        | Number               |      Yes | Maximum number of inventory items                 |
| `receiptScanQuota` | Number               |      Yes | Maximum receipt scans per month; null = unlimited |
| `isActive`         | Boolean              |      Yes | Membership availability                           |
| `createdAt`        | Timestamp            |      Yes | Creation time                                     |
| `updatedAt`        | Timestamp            |      Yes | Last update                                       |

MVP memberships:

```text
{
  "free": {
    "name": "Free",
    "price": 0,
    "currency": "VND",
    "durationDays": null,
    "foodLimit": 50,
    "receiptScanQuota": 5,
    "isActive": true
  },
  "premium": {
    "name": "Premium",
    "price": 29000,
    "currency": "VND",
    "durationDays": 30,
    "foodLimit": null,
    "receiptScanQuota": null,
    "isActive": true
  }
}
```

Membership configuration should be stored in Firestore instead of hard-coding membership configuration throughout the Flutter application.

---

# 5. Collection: foods

**Path**

```text
foods/{foodId}
```

| Field            | Type                 | Required | Description                         |
| ---------------- | -------------------- | -------: | ----------------------------------- |
| `foodId`         | String (Document ID) |      Yes | Unique food identifier, e.g. tomato |
| `name`           | String               |      Yes | Standard food name                  |
| `normalizedName` | String               |      Yes | Normalized name                     |
| `categoryId`     | String               |      Yes | Reference to category               |
| `defaultUnit`    | String               |      Yes | Default measurement unit            |
| `aliases`        | Array<String>        |       No | Alternative names                   |
| `photoUrl`       | String               |      Yes | URL of the food image               |
| `isActive`       | Boolean              |      Yes | Whether food is active              |
| `createdAt`      | Timestamp            |      Yes | Creation time                       |
| `updatedAt`      | Timestamp            |      Yes | Last update                         |

---

# 6. Collection: food_categories

**Path**

```text
food_categories/{categoryId}
```

| Field              | Type                 | Required | Description                                                                                     |
| ------------------ | -------------------- | -------: | ----------------------------------------------------------------------------------------------- |
| `categoryId`       | String (Document ID) |      Yes | Unique category identifier, e.g. `vegetables`                                                   |
| `name`             | String               |      Yes | Category name, e.g. `Rau củ`                                                                    |
| `code`             | String               |      Yes | Category code, e.g. `VEGETABLES`                                                                |
| `icon`             | String               |      Yes | Icon identifier                                                                                 |
| `defaultShelfLife` | Map                  |       No | Fallback shelf-life duration for custom/unknown foods without an exact rule in shelf_life_rules |
| `isActive`         | Boolean              |      Yes | Whether category is active                                                                      |
| `createdAt`        | Timestamp            |      Yes | Creation time                                                                                   |
| `updatedAt`        | Timestamp            |      Yes | Last update                                                                                     |

> **Cấu trúc `defaultShelfLife` (Hạn sử dụng dự phòng theo danh mục)**:
> Cung cấp thời hạn bảo quản tham chiếu mặc định khi người dùng thêm món ăn tự do (hoặc scan hóa đơn ra món mới) mà không có sẵn rule chi tiết trong `shelf_life_rules`:
>
> ```json
> {
>   "fridge": { "minValue": 3, "maxValue": 5, "unit": "days" },
>   "freezer": { "minValue": 3, "maxValue": 6, "unit": "months" }
> }
> ```

---

# 7. Collection: storage_locations

**Path**

```text
storage_locations/{locationId}
```

| Field        | Type                 | Required | Description                                          |
| ------------ | -------------------- | -------: | ---------------------------------------------------- |
| `locationId` | String (Document ID) |      Yes | Unique location identifier, e.g. `fridge`, `freezer` |
| `name`       | String               |      Yes | Storage location name, e.g. `Ngăn mát`               |
| `code`       | String               |      Yes | Unique location code, e.g. `FRIDGE`                  |
| `isActive`   | Boolean              |      Yes | Whether the storage location is active               |
| `createdAt`  | Timestamp            |      Yes | Creation time                                        |
| `updatedAt`  | Timestamp            |      Yes | Last update                                          |

MVP storage locations:

```text
{
  "fridge": {
    "name": "Ngăn mát",
    "code": "FRIDGE",
    "isActive": true,
    "createdAt": "serverTimestamp",
    "updatedAt": "serverTimestamp"
  },
  "freezer": {
    "name": "Ngăn đông",
    "code": "FREEZER",
    "isActive": true,
    "createdAt": "serverTimestamp",
    "updatedAt": "serverTimestamp"
  }
}
```

---

# 8. Collection: households

**Path**

```text
households/{householdId}
```

| Field             | Type          | Required | Description                                                          |
| ----------------- | ------------- | -------: | -------------------------------------------------------------------- |
| `name`            | String        |      Yes | Household name, e.g. "My Home"                                       |
| `ownerId`         | String        |      Yes | Reference to the owner's userId                                      |
| `members`         | Array<String> |      Yes | Array of userIds who have access to this household                   |
| `activeItemCount` | Number        |      Yes | Real-time count of active items in fridge/freezer (maintained by CF) |
| `createdAt`       | Timestamp     |      Yes | Creation time                                                        |
| `updatedAt`       | Timestamp     |      Yes | Last update                                                          |

> **Cơ chế Counter `activeItemCount`**:
>
> - Lưu trữ số lượng thực phẩm đang còn sử dụng (`status == 'active'`) trong tủ lạnh/tủ đông của gia đình.
> - Được quản lý an toàn và tự động cập nhật nguyên tử bằng Firestore Increment / Cloud Functions mỗi khi thêm món mới (+1), dùng hết/hủy món (-1).
> - Giúp Client và Backend kiểm tra tức thì hạn mức món ăn (`foodLimit`) theo gói Free (tối đa 30 món) mà **không cần quét lại toàn bộ database hay đếm mảng (O(1) read thay vì O(N))**, tối ưu chi phí và tốc độ load.

---

# 9. Subcollection: inventory_items

**Path**

```text
households/{householdId}/inventory_items/{inventoryItemId}
```

| Field                 | Type      | Required | Description                                                                        |
| --------------------- | --------- | -------: | ---------------------------------------------------------------------------------- |
| `foodId`              | String    |       No | Reference to master food document ID (null if user custom item / unrecognized OCR) |
| `name`                | String    |      Yes | Food name (from master food, user input, or OCR receipt)                           |
| `normalizedName`      | String    |      Yes | Lowercase unaccented name for autocomplete search across household history         |
| `categoryId`          | String    |      Yes | Reference to category ID (e.g. `vegetables`, `meat`)                               |
| `quantity`            | Number    |      Yes | Purchase quantity                                                                  |
| `unit`                | String    |      Yes | Measurement unit                                                                   |
| `remainingPercentage` | Number    |      Yes | Remaining quantity percentage, from 0 to 100                                       |
| `storageLocationId`   | String    |      Yes | Reference to storage location document ID (`fridge`, `freezer`)                    |
| `purchaseDate`        | Timestamp |      Yes | Purchase date                                                                      |
| `expirationDate`      | Timestamp |      Yes | Expiration date (calculated by rule or customized by user)                         |
| `source`              | String    |      Yes | Source of inventory item: `manual` or `receipt_scan`                               |
| `status`              | String    |      Yes | Item lifecycle status: `active`, `consumed`, `discarded`                           |
| `createdAt`           | Timestamp |      Yes | Creation time                                                                      |
| `updatedAt`           | Timestamp |      Yes | Last update                                                                        |

> **Cơ chế Vòng đời & Tự động gợi ý món (Autocomplete & Lifecycle)**:
>
> 1. **Soft Delete (`status`)**:
>    - `active`: Thực phẩm đang có trong tủ lạnh/tủ đông (hiển thị trên màn hình Tủ lạnh).
>    - `consumed`: Đã dùng hết (khi user bấm dùng hết món hoặc thanh trượt còn 0%). Món ẩn khỏi tủ lạnh nhưng được lưu lại để phục vụ gợi ý lần sau và thống kê lãng phí.
>    - `discarded`: Bị vứt bỏ do hỏng/quá hạn.
> 2. **Cơ chế tìm kiếm & gợi ý thông minh (Name Autocomplete & Smart Search Engine)**:
>    - Khi người dùng nhập vào ô `name`, App truy vấn và xếp hạng theo chuẩn Search Engine:
>      - **In-memory Caching**: Tải toàn bộ danh mục thực phẩm chuẩn `foods` (có `isActive = true`) 1 lần duy nhất trong phiên làm việc, đảm bảo tốc độ phản hồi 0ms và không giới hạn trần số lượng bản ghi.
>      - **Chuẩn hóa tiếng Việt & Tokenization**: Chuẩn hóa không dấu (`StringUtils.normalize`), tách từ khóa thành các token để người dùng gõ từ khóa không dấu hoặc đảo thứ tự từ vẫn tìm thấy chính xác.
>      - **Hỗ trợ `aliases` (Tên gọi khác)**: Tìm kiếm đồng thời trên `name`, `normalizedName` và toàn bộ mảng `aliases` (ví dụ: gõ "thịt lợn" ra "Thịt heo" kèm nhãn chú thích "Tên khác: thịt lợn").
>      - **Relevance Scoring**: Xếp hạng kết quả theo độ ưu tiên (Exact Match 100 điểm > Alias Match 95 điểm > StartsWith 85 điểm > Substring 70 điểm > Token Match 55 điểm).
>      - **Lịch sử gia đình**: Quét bổ sung danh sách món từng nhập trong `households/{householdId}/inventory_items` (kể cả món `consumed`).
>      - **Giao diện Floating Overlay**: Dropdown gợi ý nổi đè lên trên (Overlay với `elevation: 8`) giúp không làm co đẩy các input bên dưới, tự động ẩn khi bấm ra ngoài hoặc cuộn màn hình.
> 3. **Trường hợp thêm món mới không có trong danh sách**:
>    - `foodId = null`, `name` do user nhập, `categoryId` do user chọn.
>    - `expirationDate`: Tự động tính dựa theo `defaultShelfLife` của `categoryId` đó. User có thể chọn lại ngày khác tùy ý.
>    - Sau khi lưu, món này trở thành một phần trong lịch sử của household, các lần nhập sau gõ tên sẽ tự động xuất hiện trong danh sách gợi ý!

---

# 10. Collection: shelf_life_rules

**Path**

```text
shelf_life_rules/{ruleId}
```

| Field               | Type      | Required | Description                                                                       |
| ------------------- | --------- | -------: | --------------------------------------------------------------------------------- |
| `foodId`            | String    |      Yes | Reference to food document ID                                                     |
| `storageLocationId` | String    |      Yes | Reference to storage location document ID (`fridge`, `freezer`)                   |
| `minValue`          | Number    |       No | Minimum recommended storage duration (null nếu không khuyến nghị)                 |
| `maxValue`          | Number    |       No | Maximum recommended storage duration (null nếu không khuyến nghị)                 |
| `unit`              | String    |       No | Unit of duration: `days`, `weeks`, `months`, `years` (null nếu không khuyến nghị) |
| `isActive`          | Boolean   |      Yes | Whether the rule is active                                                        |
| `createdAt`         | Timestamp |      Yes | Creation time                                                                     |
| `updatedAt`         | Timestamp |      Yes | Last update                                                                       |

> **Cách tính hạn sử dụng (Expiration Date Calculation)**:
> Khi thêm thực phẩm vào kho (hoặc quét hóa đơn), hệ thống tính tự động:
> `expirationDate = purchaseDate + maxValue` theo `unit` (ví dụ: `purchaseDate + 6 months` hoặc `purchaseDate + 4 days`).
> Nếu `maxValue` là null (không khuyến nghị bảo quản ở vị trí này), app cảnh báo người dùng.

---

# 11. Collection: receipts

**Path**

```text
users/{userId}/receipts/{receiptId}
```

| Field         | Type      | Required | Description                                                       |
| ------------- | --------- | -------: | ----------------------------------------------------------------- |
| `householdId` | String    |      Yes | Reference to the destination household ID                         |
| `imageUrl`    | String    |       No | Receipt image URL                                                 |
| `status`      | String    |      Yes | Processing status: `pending`, `processing`, `completed`, `failed` |
| `ocrText`     | String    |       No | Raw text extracted from receipt                                   |
| `processedBy` | String    |       No | OCR/AI model or service used to process the receipt               |
| `createdAt`   | Timestamp |      Yes | Receipt creation time                                             |
| `updatedAt`   | Timestamp |      Yes | Last update time                                                  |

---

# 12. Subcollection: receipt_items

**Path**

```text
users/{userId}/receipts/{receiptId}/items/{receiptItemId}
```

| Field            | Type   | Required | Description                                                                               |
| ---------------- | ------ | -------: | ----------------------------------------------------------------------------------------- |
| `rawName`        | String |      Yes | Original product name extracted directly from the receipt by OCR (e.g. `THIT BA ROI C.P`) |
| `normalizedName` | String |      Yes | Standardized lowercase food name after text normalization (`thit ba roi c.p`)             |
| `foodId`         | String |       No | Reference to the matched master food document ID (null if not found in master foods)      |
| `categoryId`     | String |       No | Detected or mapped category ID                                                            |
| `quantity`       | Number |      Yes | Quantity of the food detected from the receipt                                            |
| `unit`           | String |      Yes | Measurement unit, e.g. `kg`, `g`, `hộp`, `gói`                                            |
| `confidence`     | Number |       No | Confidence score of the food recognition/matching result (0.0 to 1.0)                     |

> **Quy trình Nhận diện Hóa đơn & Tìm Shelf Life Rule (Receipt Matching Flow)**:
>
> 1. **Giữ nguyên văn tên trên hóa đơn (`rawName`)**:
>    - Khi tạo `inventory_item` từ hóa đơn, trường `name` của item sẽ lấy theo `rawName` (hoặc cho user tùy ý sửa) để người dùng dễ đối chiếu với hóa đơn mua hàng thực tế.
> 2. **Chuẩn hóa chuỗi (`normalizedName`) để tìm rule**:
>    - Hệ thống dùng `normalizedName` đối soát với `normalizedName` và mảng `aliases` của collection `foods`.
>    - **Nếu tìm thấy `foodId`**: Map theo rule chính xác của `foodId` đó trong `shelf_life_rules` $\rightarrow$ Tự động điền ngày hết hạn khuyến nghị (`expirationDate`).
>    - **Nếu KHÔNG tìm thấy trong `foods`**:
>      - Nhận diện hoặc để user chọn `categoryId`.
>      - Áp dụng `defaultShelfLife` của `categoryId` đó để tự động gợi ý ngày hết hạn dự phòng.
>      - Khi user bấm xác nhận nhập vào kho, món ăn sẽ tự động lưu vào lịch sử kho của gia đình (`status: 'active'`) $\rightarrow$ Phục vụ gợi ý tự động cho các lần sau!

---

# 13. Collection: notifications

**Path**

```text
users/{userId}/notifications/{notificationId}
```

| Field             | Type      | Required | Description                                                                             |
| ----------------- | --------- | -------: | --------------------------------------------------------------------------------------- |
| `householdId`     | String    |       No | Reference to the related household ID (if applicable)                                   |
| `type`            | String    |      Yes | Notification type: `expiration_alert`, `upcoming_expiration`, `priority_food`, `system` |
| `title`           | String    |      Yes | Notification title displayed to the user                                                |
| `message`         | String    |      Yes | Notification message displayed to the user                                              |
| `inventoryItemId` | String    |       No | Reference to the related inventory item                                                 |
| `isRead`          | Boolean   |      Yes | Whether the user has read the notification                                              |
| `createdAt`       | Timestamp |      Yes | Notification creation time                                                              |

---

# 14. Collection: devices

**Path**

```text
users/{userId}/devices/{deviceId}
```

| Field       | Type      | Required | Description                            |
| ----------- | --------- | -------: | -------------------------------------- |
| `fcmToken`  | String    |      Yes | FCM registration token for the device  |
| `platform`  | String    |      Yes | Device platform, e.g. `android`, `ios` |
| `isActive`  | Boolean   |      Yes | Whether the device/token is active     |
| `createdAt` | Timestamp |      Yes | Device registration time               |
| `updatedAt` | Timestamp |      Yes | Last update time                       |

---

# 15. Collection: ai_usage

**Path**

```text
users/{userId}/ai_usage/current
```

| Field             | Type      | Required | Description                     |
| ----------------- | --------- | -------: | ------------------------------- |
| `period`          | String    |      Yes | Usage period, e.g. `2026-08`    |
| `receiptScanUsed` | Number    |      Yes | Number of AI receipt scans used |
| `updatedAt`       | Timestamp |      Yes | Last usage update time          |

---

# 16. Collection: subscriptions

**Path**

```text
users/{userId}/subscriptions/{subscriptionId}
```

| Field               | Type      | Required | Description                                                   |
| ------------------- | --------- | -------: | ------------------------------------------------------------- |
| `membershipId`      | String    |      Yes | Reference to the membership document ID                       |
| `status`            | String    |      Yes | Subscription status, e.g. `active`, `cancelled`, `expired`    |
| `startDate`         | Timestamp |      Yes | Subscription start date                                       |
| `endDate`           | Timestamp |      Yes | Current subscription expiration date                          |
| `autoRenew`         | Boolean   |      Yes | Whether the subscription is set to renew automatically        |
| `cancelAtPeriodEnd` | Boolean   |      Yes | Whether subscription will cancel at current billing cycle end |
| `platform`          | String    |      Yes | Purchase platform: `android` or `ios`                         |
| `productId`         | String    |      Yes | Store product ID                                              |
| `purchaseToken`     | String    |       No | Purchase token/transaction reference when applicable          |
| `createdAt`         | Timestamp |      Yes | Subscription creation time                                    |
| `updatedAt`         | Timestamp |      Yes | Last update time                                              |

---

# 17. Collection: payments

**Path**

```text
users/{userId}/payments/{paymentId}
```

| Field            | Type      | Required | Description                           |
| ---------------- | --------- | -------: | ------------------------------------- |
| `subscriptionId` | String    |      Yes | Reference to the related subscription |
| `membershipId`   | String    |      Yes | Purchased membership ID               |
| `amount`         | Number    |      Yes | Transaction amount                    |
| `currency`       | String    |      Yes | Currency code                         |
| `platform`       | String    |      Yes | `android` or `ios`                    |
| `productId`      | String    |      Yes | Store product ID                      |
| `transactionId`  | String    |      Yes | Transaction ID from the store         |
| `status`         | String    |      Yes | Payment status                        |
| `createdAt`      | Timestamp |      Yes | Payment time                          |

---

# 18. Relationships

```text
users
│
├── membershipId ────────────→ memberships
├── activeHouseholdId ───────→ households
│
├── receipts
│   ├── householdId ─────────→ households
│   └── items (receipt_items)
│       └── foodId ────────────→ foods
│
├── notifications
│   ├── householdId ─────────→ households
│   └── inventoryItemId ───────→ households/{householdId}/inventory_items
│
├── subscriptions
│   └── membershipId ──────────→ memberships
│
└── payments
    ├── subscriptionId ────────→ subscriptions
    └── membershipId ──────────→ memberships


households
│
├── members (array contains userIds) ──→ users
│
└── inventory_items
    ├── foodId (optional) ─────→ foods
    ├── categoryId ────────────→ food_categories
    └── storageLocationId ─────→ storage_locations


foods
└── categoryId ────────────────→ food_categories


shelf_life_rules
├── foodId ────────────────────→ foods
└── storageLocationId ────────→ storage_locations
```

---

# 19. Firebase Storage Structure & Image Handling Strategy

```text
Storage
│
├── system/
│   ├── foods/
│   │   └── {foodId}.webp            # Master food image (named deterministically after foodId)
│   └── categories/
│       └── {categoryId}.webp       # Category default icon / illustration
│
└── users/
    └── {userId}/
        ├── receipts/
        │   └── {receiptId}/
        │       └── {fileName}
        └── custom_foods/
            └── {customFoodId}.webp  # User-captured / uploaded custom food photo
```

### 19.1. System Foods Image Strategy

- **File Naming & Format**: Standardized as `{foodId}.webp` (optimized 500x500 px, ~20-40KB) for fast load times and minimal storage cost.
- **Client Derivation**: App can resolve URLs dynamically:
  ```text
  imageUrl = food.photoUrl ?? "${IMAGE_BASE_URL}/system/foods/${food.foodId}.webp"
  ```
- **Caching**: Configured with `Cache-Control: public, max-age=31536000` (1 year CDN cache).

### 19.2. Custom Foods & User Generated Items (Expansion Strategy)

When a user adds a food item not present in the master `foods` collection:

1. **User takes photo**:
   - Client resizes/compresses image to ~500x500 px `.webp`.
   - Uploads to `users/{userId}/custom_foods/{customFoodId}.webp`.
   - Stores the generated download URL in `inventory_items.photoUrl`.
2. **User skips photo**:
   - `inventory_items.photoUrl` is set to `null`.
   - **Category Fallback**: Client automatically displays the category default illustration (`system/categories/{categoryId}.webp` or vector icon).
   - **Initial Avatar Fallback**: Client renders a stylish pastel avatar containing the first letter of `customName`.
   - **AI Suggestion**: Gemini / Smart Match maps the item name to the closest existing master food illustration if applicable.

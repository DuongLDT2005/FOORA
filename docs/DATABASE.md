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
│       ├── ai_chats
│       │   └── {messageId}
│       ├── ai_sessions
│       │   └── {sessionId}
│       ├── ai_requests
│       │   └── {requestId}
│       ├── ai_usage_days
│       │   └── {YYYY-MM-DD}
│       │
│       └── payments
│           └── {paymentId}
│
├── households
│   └── {householdId}
│       ├── inventory_items
│       │   └── {inventoryItemId}
│       │
│       └── shopping_lists
│           └── {shoppingListId}
│               └── items
│                   └── {shoppingItemId}
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
├── shelf_life_rules
│   └── {ruleId}
│
└── bug_reports
    └── {reportId}
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
| `avatarUrl`         | String    |       No | Profile photo URL (Storage)      |
| `notificationSettings` | Map    |       No | Reminder preferences read by `hourlyReminderCron` (see below) |
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
> - `email`: The owner may only sync it to the **verified** email of the Firebase Auth token (`request.auth.token.email`, `email_verified == true`). An email change is requested with `verifyBeforeUpdateEmail`; the client copies the new address after the user confirms the link.
> - `role`, `membershipId`, `isActive`, `activeHouseholdId`, `createdAt`: System-protected fields strictly guarded by Security Rules; clients cannot mutate them (managed exclusively via Cloud Functions / Admin SDK).
> - Create: the `onUserCreated` trigger creates the document. If the client writes first, it may only create `fullName` and `updatedAt`.
> - `notificationSettings`: the owner may write it; Rules validate every key (see below) and require `updatedAt == request.time`.

**`notificationSettings` (PLAN_02)**

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `pushEnabled` | Boolean | `true` | Off = no expiry or shopping reminders |
| `expiryAlertDays` | Array<Number> | `[1, 3]` | Subset of `[1, 3, 7]`: days before expiry that send `upcoming_expiration` |
| `reminderHour` | Number (int) | `8` | Vietnam hour 0–23 for expiry and shopping reminders |
| `shoppingReminderEnabled` | Boolean | `true` | Weekly "time to go shopping" reminder |
| `shoppingReminderWeekday` | Number (int) | `6` | ISO weekday, 1 = Monday … 7 = Sunday |
| `updatedAt` | Timestamp | | Last change |

The app writes defaults (merged with the old on-device `pref_notif_*` values) after sign-in when the field is missing, because the backend cannot query users without it. Users who have not opened the new app version receive no reminders until they do. Notification sound stays on the device only.

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
| `memberLimit`      | Number               |      Yes | Max people in a household the user owns (owner included); null = unlimited (still capped at 20) |
| `aiAssistantDailyQuota` | Number \| null | Yes | Maximum successful assistant requests per Vietnam day; null = unlimited |
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
    "foodLimit": 30,
    "receiptScanQuota": 5,
    "memberLimit": 3,
    "aiAssistantDailyQuota": 10,
    "isActive": true
  },
  "premium": {
    "name": "Premium",
    "price": 29000,
    "currency": "VND",
    "durationDays": 30,
    "foodLimit": null,
    "receiptScanQuota": null,
    "memberLimit": 10,
    "aiAssistantDailyQuota": null,
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
> - Giúp Client và Backend kiểm tra tức thì hạn mức món ăn (`foodLimit`, đọc từ `memberships/{membershipId}`) mà **không cần quét lại toàn bộ database hay đếm mảng (O(1) read thay vì O(N))**, tối ưu chi phí và tốc độ load.
>
> **Security Rules**: Household được tạo bởi Cloud Functions. Chỉ **owner** được sửa `name` và `updatedAt`; `members`, `ownerId`, `activeItemCount` là field do backend quản lý (join/leave/remove qua callable `household`).
>
> **Chia sẻ household (PLAN_05)**:
>
> - **D1** – `foodLimit` của household tính theo gói của **owner** (`MembershipService.resolveMembershipId(household.ownerId)`), không theo người thêm món.
> - **D2** – Số người tối đa (kể cả owner) theo `memberships/{id}.memberLimit` của **owner**: Free **3**, Premium **10**; luôn bị chặn trần kỹ thuật **20** (`MAX_HOUSEHOLD_MEMBERS`). Household đầy → join bị từ chối (`failed-precondition`) và owner nhận notification gợi ý nâng cấp. Hạ gói không xóa thành viên hiện có, chỉ chặn người mới.
> - **D3** – Mã mời hết hạn sau **7 ngày**; tạo mã mới sẽ thu hồi mã cũ.
> - **D4** – Join household khác: household cũ giữ nguyên dữ liệu, chỉ đổi `users.activeHouseholdId`. Rời/bị xóa → quay về household mà user là `ownerId` (tạo mới nếu chưa có).

## 8.1 Collection: household_invitations (server-only)

**Path**: `household_invitations/{code}` – doc id chính là mã mời 6 ký tự (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`, bỏ `0 O 1 I L`). QR trong app chỉ chứa đúng mã này.

| Field           | Type      | Required | Description                                  |
| --------------- | --------- | -------: | -------------------------------------------- |
| `code`          | String    |      Yes | Trùng doc id                                 |
| `householdId`   | String    |      Yes | Household được mời vào                       |
| `householdName` | String    |      Yes | Tên household lúc tạo mã (snapshot)          |
| `createdBy`     | String    |      Yes | uid owner                                    |
| `status`        | String    |      Yes | `active`, `revoked`, `expired`               |
| `useCount`      | Number    |      Yes | Số người đã join bằng mã                     |
| `expiresAt`     | Timestamp |      Yes | `createdAt + 7 ngày`                         |
| `createdAt`     | Timestamp |      Yes |                                              |
| `updatedAt`     | Timestamp |      Yes |                                              |

## 8.2 Collection: invite_attempts (server-only)

**Path**: `invite_attempts/{userId}` – chống dò mã: `{ failedCount: Number, windowStart: Timestamp }`. Quá **10** lần nhập sai trong **1 giờ** → `resource-exhausted`; join thành công thì xóa doc.

> **Security Rules**: cả hai collection `allow read, write: if false` (chỉ Admin SDK).

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
| `quantity`            | Number    |      Yes | Current remaining quantity in this batch                                            |
| `initialQuantity`     | Number    |      Yes | Positive baseline quantity; new batch starts with `initialQuantity = quantity`     |
| `unit`                | String    |      Yes | Measurement unit                                                                   |
| `remainingPercentage` | Number    |      Yes | `round(quantity / initialQuantity * 100)`, limited to 0..100                        |
| `initialQuantityMigration` | String | No | `inferred` or `reset` for old batches processed by the backfill              |
| `storageLocationId`   | String    |      Yes | Reference to storage location document ID (`fridge`, `freezer`)                    |
| `purchaseDate`        | Timestamp |      Yes | Purchase date                                                                      |
| `expirationDate`      | Timestamp |      Yes | Expiration date (calculated by rule or customized by user)                         |
| `photoUrl`            | String    |       No | Food photo URL (from master food, or null to fallback to category icon)           |
| `source`              | String    |      Yes | Source of inventory item: `manual` or `receipt_scan`                               |
| `status`              | String    |      Yes | Item lifecycle status: `active`, `consumed`, `discarded`                           |
| `statusChangedAt`     | Timestamp |       No | Timestamp when status transitioned to `consumed`/`discarded` (for Waste Statistics) |
| `createdAt`           | Timestamp |      Yes | Creation time                                                                      |
| `updatedAt`           | Timestamp |      Yes | Last update                                                                        |

> **Security Rules**: Client **không** được tạo hoặc xóa `inventory_items` trực tiếp; món mới phải đi qua callable `addInventoryItem` / `batchAddInventoryItems` hoặc action AI đã duyệt để backend kiểm tra `foodLimit`. Thành viên household chỉ được cập nhật các field nội dung (`name`, `quantity`, `initialQuantity`, `unit`, `remainingPercentage`, `storageLocationId`, `purchaseDate`, `expirationDate`, `categoryId`, `foodId`, `normalizedName`, `photoUrl`, `status`, `statusChangedAt`, `updatedAt`) với `quantity <= initialQuantity` và phần trăm tương ứng; không được chuyển món `consumed`/`discarded` về `active`. Khi cập nhật `status`, `statusChangedAt` phải bằng `request.time`. Backfill `initialQuantity` chạy dry-run trên Emulator bằng `cd functions && npm run backfill:initial-quantity`; chỉ thêm `-- --apply` sau khi xem báo cáo. Script này không ghi production.

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
> 4. **Cơ chế gán ảnh thực phẩm & Fallback Icon theo Category**:
>    - **Khi món nằm trong Master Foods (`foodId != null`)**: Cả hai luồng nhập tay (Form) và Quét hóa đơn (Receipt Scan / Cloud Function) tự động gắn URL ảnh `photoUrl` của món từ `foods/{foodId}` vào `inventory_items.photoUrl`.
>    - **Khi món tùy biến hoặc không có ảnh (`photoUrl == null`)**: Client dùng widget dùng chung `FoodImageAvatar` để tự động render Icon đại diện của danh mục (`food_categories/{categoryId}.icon`, ví dụ `lucide-carrot`, `lucide-beef`, `lucide-apple`), đảm bảo giao diện luôn đồng bộ, đẹp mắt và không bao giờ bị vỡ ảnh.

---

# 9.1 Subcollection: shopping_lists

**Path**

```text
households/{householdId}/shopping_lists/{shoppingListId}
```

A household can have several lists; every member sees them in real time.

| Field       | Type      | Required | Description                     |
| ----------- | --------- | -------: | ------------------------------- |
| `name`      | String    |      Yes | 1–100 characters                |
| `note`      | String    |       No | ≤ 200 characters                |
| `createdBy` | String    |      Yes | uid of the creator              |
| `createdAt` | Timestamp |      Yes | Creation time                   |
| `updatedAt` | Timestamp |      Yes | Last change of the list itself  |

> **Security Rules**: members read, create and rename lists. Clients cannot delete a list; the `deleteShoppingList` callable deletes it with its items (recursive delete).

## 9.2 Subcollection: shopping list items

**Path**

```text
households/{householdId}/shopping_lists/{shoppingListId}/items/{shoppingItemId}
```

| Field                | Type      | Required | Description                                                         |
| -------------------- | --------- | -------: | ------------------------------------------------------------------- |
| `name`               | String    |      Yes | 1–100 characters                                                    |
| `normalizedName`     | String    |      Yes | `StringUtils.normalize(name)`, used for merging and suggestions     |
| `foodId`             | String    |       No | Master food picked from autocomplete                                |
| `categoryId`         | String    |       No | Suggested category; required (and not `other`) when imported        |
| `quantity`           | Number    |      Yes | 0 < quantity ≤ 10000                                                |
| `unit`               | String    |      Yes | 1–20 characters                                                     |
| `note`               | String    |       No | ≤ 200 characters                                                    |
| `source`             | String    |      Yes | `manual`, `voice`, `suggestion`, `ai_recipe`                        |
| `isPurchased`        | Boolean   |      Yes | Ticked as bought                                                    |
| `purchasedBy`        | String    |       No | uid who ticked it (`null` when not purchased)                       |
| `purchasedAt`        | Timestamp |       No | Server time of the tick                                             |
| `isAddedToInventory` | Boolean   |      Yes | Moved into the fridge (backend only)                                |
| `inventoryItemId`    | String    |       No | Inventory batch created on import (backend only)                    |
| `addedToInventoryAt` | Timestamp |       No | Import time (backend only)                                          |
| `addedBy`            | String    |      Yes | uid who added it (`request.auth.uid`)                               |
| `createdAt`          | Timestamp |      Yes | Creation time                                                       |
| `updatedAt`          | Timestamp |      Yes | Last update                                                         |

> **Merge rule**: adding an item whose `normalizedName` and `unit` match a not-yet-purchased item in the same list increases that item's quantity instead of creating a duplicate (client transaction).
>
> **Security Rules**: members create items with `isPurchased == false`, `isAddedToInventory == false`, `addedBy == request.auth.uid`; they may edit, tick (`purchasedBy == request.auth.uid`, `purchasedAt == request.time`) and delete items. Items with `isAddedToInventory == true` are read-only for clients, and clients can never set the inventory fields.
>
> **Moving into the fridge**: the `importShoppingItemsToInventory` callable re-reads the items in one transaction, creates the inventory batches through `InventoryService.executeBatchAddInTransaction` (foodLimit, `activeItemCount`, expiry from shelf-life rules, `source: manual`) and marks the items imported. A retry after success returns the existing inventory ids; a concurrent import by another member fails with `failed-precondition`.

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
> Nếu không có rule lẫn `defaultShelfLife` của category, app gợi ý mặc định `AppConstants.fallbackFridgeShelfLifeDays` (3 ngày, ngăn mát) / `AppConstants.fallbackFreezerShelfLifeDays` (30 ngày, ngăn đông) và người dùng có thể sửa lại.

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
| `photoUrl`       | String |       No | URL ảnh thực phẩm (tự động lấy từ master foods nếu khớp, null nếu là món tùy biến)         |
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
> 3. **Tự động gắn `photoUrl` cho món từ hóa đơn**:
>    - Khi Gemini AI / Rule-based parser khớp món với Master Foods (`foodId != null`), `photoUrl` của món tương ứng sẽ tự động được gán vào `receipt_items` và chuyển tiếp vào `inventory_items` khi lưu theo lô (`batchAddInventoryItems`).
>    - Nếu backend nhận món có `foodId` mà thiếu `photoUrl`, `InventoryService` tự động query từ document `foods/{foodId}` để bổ sung trước khi commit transaction vào Firestore.

---

# 13. Collection: notifications

**Path**

```text
users/{userId}/notifications/{notificationId}
```

| Field             | Type      | Required | Description                                                                             |
| ----------------- | --------- | -------: | --------------------------------------------------------------------------------------- |
| `householdId`     | String    |       No | Reference to the related household ID (if applicable)                                   |
| `type`            | String    |      Yes | Notification type: `expiration_alert`, `upcoming_expiration`, `priority_food`, `shopping_reminder`, `system` |
| `title`           | String    |      Yes | Notification title displayed to the user                                                |
| `message`         | String    |      Yes | Notification message displayed to the user                                              |
| `inventoryItemId` | String    |       No | Reference to the related inventory item                                                 |
| `isRead`          | Boolean   |      Yes | Whether the user has read the notification                                              |
| `createdAt`       | Timestamp |      Yes | Notification creation time                                                              |

Notification ids are deterministic so a retried job never sends twice: expiry `{YYYYMMDD}_{type}_{inventoryItemId}`, weekly shopping reminder `shopping_{YYYY}W{ww}` (ISO week, Vietnam date). `expiration_alert` is sent once, the day after expiry; `upcoming_expiration` only on the user's `expiryAlertDays`. A `shopping_reminder` push opens the shopping lists.

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

## 15.1 AI assistant chat, requests, and daily usage

- `users/{userId}/ai_chats/{messageId}`: server-written conversation records. Fields: `householdId`, `sessionId`, `requestId`, `content`, `isUser`, `createdAt`; user messages also have `inputMode` (`text` or `voice`); assistant messages have `model`, validated `recipes` (`title`, `servings?`, `ingredients[]` gồm `name`, `quantity?`, `unit?`, `itemId?` — có `itemId` là lấy từ kho, không có là cần mua; kèm `usesRefs`/`usedIngredients`/`missingIngredients` suy ra từ `ingredients`; không có bước nấu, tin cũ có thể còn `steps`) và `actions` (ID đề xuất, batch ứng viên/snapshot, `reviewState`, `resolution`; `add_inventory` được khớp với `foods` bằng bộ chấm điểm dùng chung với quét hóa đơn (`functions/src/inventory/services/food_matcher.ts`) nên có thêm `foodId`, `photoUrl`, `spokenName` khi lời nói khác tên chuẩn và `expirationDate` dự kiến). Khi duyệt action, lưu thêm `actionStatus`, `decisionsHash`, `applyResult` atomically. Owners may read, but only Cloud Functions may write. Query lịch sử lọc `sessionId` trước khi lấy 50 tin; composite index nằm trong `firestore.indexes.json`. Tin tạo trước khi có session không có `sessionId` nên không hiện trong lịch sử.
- `users/{userId}/ai_sessions/{sessionId}`: server-written conversation summary cho màn lịch sử chat. Fields: `householdId`, `title` (câu hỏi đầu, ≤ 80 ký tự), `lastMessage` (câu trả lời mới nhất, ≤ 140 ký tự), `messageCount`, `createdAt`, `updatedAt`. Owners may read, only Cloud Functions may write; client liệt kê theo `householdId` + `updatedAt desc` (composite index). Một session chỉ thuộc một household.
- `users/{userId}/ai_requests/{requestId}`: server-only idempotency record. Fields: `payloadHash`, `householdId`, `status` (`pending`, `completed`, `failed`), `quotaDay`, `quotaReserved`, `attemptId`, `leaseExpiresAt`, `result`, `updatedAt`.
- `users/{userId}/ai_usage_days/{YYYY-MM-DD}`: server-written daily counter with `used` and `updatedAt`; owners may read. Day boundaries use `Asia/Ho_Chi_Minh`. Receipt usage in `ai_usage/current` remains separate.

`aiAssistant` trả lời và đề xuất; nó không thay đổi kho. `applyAiActions` chỉ áp dụng các action đã lưu sau khi user xác nhận, kiểm tra lại quyền và snapshot trong transaction. Retry cùng decisions trả lại `applyResult`; decisions khác cho cùng message bị từ chối.

# 16. Collection: subscriptions

**Path**

```text
users/{userId}/subscriptions/{subscriptionId}
```

Document ID convention: `{provider}_{membershipId}` (e.g. `payos_premium`), so
repeated purchases of the same plan extend one document.

Flutter mapping: entity `Subscription`
(`lib/features/membership/domain/entities/subscription.dart`) and
`SubscriptionModel` (`lib/features/membership/data/models/subscription_model.dart`).

| Field | Type | Required | Entity field (default) | Description |
| --- | --- | ---: | --- | --- |
| *(document ID)* | String | Yes | `id` | Subscription ID, e.g. `payos_premium` |
| `membershipId` | String | Yes | `membershipId` | Reference to `memberships/{membershipId}` |
| `provider` | String | Yes | `provider` | Payment provider that granted the entitlement; `payos` |
| `status` | String | Yes | `status` (`SubscriptionStatus`) | `active`, `cancelled`, or `expired` |
| `startDate` | Timestamp | Yes | `startDate` | Initial entitlement start (kept when the period is extended) |
| `endDate` | Timestamp | Yes | `endDate` | Current entitlement expiration |
| `autoRenew` | Boolean | Yes | `autoRenew` (`false`) | Always `false` for payOS |
| `cancelAtPeriodEnd` | Boolean | Yes | `cancelAtPeriodEnd` (`false`) | Whether access ends at the current period |
| `lastPaymentId` | String | Yes | `lastPaymentId` (nullable) | Most recent `payments/{paymentId}` that extended entitlement |
| `createdAt` | Timestamp | Yes | `createdAt` | Creation time |
| `updatedAt` | Timestamp | Yes | `updatedAt` | Last update time |

Legacy IAP fields (`platform`, `productId`, `purchaseToken`) are no longer part
of the schema and are ignored by the app.

**Writes**: backend only (Firestore Rules deny all client writes). The payOS
webhook creates/extends the document in the same transaction that completes the
payment: `endDate = max(paidAt, currentEndDate) + durationDays`. The
`maintenanceSweepCron` scheduler (`expireOverduePayments`) moves `active` subscriptions whose `endDate`
has passed to `expired`.

**Entitlement** (source of truth for Premium): a subscription grants its plan
when `status == 'active'`, `startDate <= now` and `endDate > now`
(`Subscription.isEntitledAt(now)` in Flutter, `pickActiveSubscription` in
`functions/src/membership/services/entitlement.ts`). If several match, the one
with the furthest `endDate` wins; with none, the user is on `free`.

`users.membershipId` is only a derived cache. The backend recomputes it from
subscriptions (`MembershipService.syncMembershipCache`) on activation and
expiry, and never uses it for authorization, limits or quota.

payOS subscriptions never auto-renew, so the app does not offer an auto-renew
toggle: the user renews by paying again.

---

# 17. Collection: payments

**Path**

```text
users/{userId}/payments/{paymentId}
```

| Field | Type | Required | Description |
| --- | --- | ---: | --- |
| `membershipId` | String | Yes | Purchased membership ID |
| `subscriptionId` | String | No | Subscription activated by a completed payment |
| `provider` | String | Yes | `payos` |
| `providerRequestId` | String | No | payOS payment link ID |
| `providerTransactionId` | String | No | Unique incoming bank transaction ID |
| `referenceNumber` | String | Yes | Unique opaque FOORA payment reference |
| `amount` | Number | Yes | Server-resolved amount |
| `currency` | String | Yes | `VND` |
| `status` | String | Yes | `pending`, `completed`, `failed`, `cancelled`, `expired`, or `requires_review` |
| `qrCode` | String | No | QR payload returned by Cas |
| `virtualAccountNumber` | String | No | Destination virtual account |
| `description` | String | Yes | Required transfer description |
| `durationDays` | Number | Yes | Server snapshot used for activation |
| `expiresAt` | Timestamp | Yes | Payment deadline |
| `paidAt` | Timestamp | No | Bank transaction time |
| `cancelledAt` | Timestamp | No | Cancellation time |
| `reviewReason` | String | No | Reason manual review is required |
| `createdAt` | Timestamp | Yes | Creation time |
| `updatedAt` | Timestamp | Yes | Last update time |

Clients may read only their own payment documents. All writes are backend-only.

## 17.1 Collection: payment_order_locks

**Path:** `payment_order_locks/{lockId}`

Server-only lock used to serialize create-order requests per user and membership.
Firestore Rules deny all client reads and writes.

## 17.2 Collection: payment_references

**Path:** `payment_references/{referenceNumber}`

Server-only lookup mapping a payOS order code to `userId` and `paymentId`.
Firestore Rules deny all client reads and writes.

## 17.3 Collection: payment_provider_transactions

**Path:** `payment_provider_transactions/{providerTransactionId}`

Server-only idempotency ledger. The provider transaction ID is the document ID so
one bank transaction cannot activate more than one payment.

---

# 17.4 Collection: bug_reports

**Path**

```text
bug_reports/{reportId}
```

| Field           | Type      | Required | Description                                   |
| --------------- | --------- | -------: | --------------------------------------------- |
| `userId`        | String    |      Yes | Reporter (must equal the authenticated uid)   |
| `userEmail`     | String    |      Yes | Reporter email                                |
| `category`      | String    |      Yes | Report category selected in the app           |
| `title`         | String    |      Yes | Short summary                                 |
| `description`   | String    |      Yes | Details                                       |
| `screenshotUrl` | String    |       No | Screenshot in Storage `bug_reports/{userId}/` |
| `deviceInfo`    | String    |       No | Device / OS / app version                     |
| `createdAt`     | Timestamp |      Yes | Creation time                                 |

Clients may only create their own reports; reads, updates and deletes are
server/admin only.

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
├── inventory_items
│   ├── foodId (optional) ─────→ foods
│   ├── categoryId ────────────→ food_categories
│   └── storageLocationId ─────→ storage_locations
│
└── shopping_lists
    └── items
        ├── foodId (optional) ─────→ foods
        ├── categoryId (optional) ─→ food_categories
        └── inventoryItemId ───────→ households/{householdId}/inventory_items


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
├── users/
│   └── {userId}/
│       ├── avatar/
│       │   └── {fileName}            # Profile photo (image/*, < 5MB, owner write)
│       ├── receipts/
│       │   └── {receiptId}/
│       │       └── {fileName}
│       └── custom_foods/
│           └── {customFoodId}.webp  # User-captured / uploaded custom food photo
│
└── bug_reports/
    └── {userId}/
        └── {fileName}                # Bug report screenshot (image/*, < 10MB, owner only)
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

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

---

# 4. Collection: memberships

**Path**

```text
memberships/{membershipId}
```

| Field              | Type                 | Required | Description                                          |
| ------------------ | -------------------- | -------: | ---------------------------------------------------- |
| `membershipId`     | String (Document ID) |      Yes | Unique membership identifier (free, premium)         |
| `name`             | String               |      Yes | Membership name                                      |
| `price`            | Number               |      Yes | Membership price                                     |
| `currency`         | String               |      Yes | Currency code                                        |
| `durationDays`     | Number               |      Yes | Membership duration                                  |
| `foodLimit`        | Number               |      Yes | Maximum number of inventory items                    |
| `receiptScanQuota` | Number               |      Yes | Maximum receipt scans per month; null = unlimited    |
| `isActive`         | Boolean              |      Yes | Membership availability                              |
| `createdAt`        | Timestamp            |      Yes | Creation time                                        |
| `updatedAt`        | Timestamp            |      Yes | Last update                                          |

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

| Field        | Type                 | Required | Description                                   |
| ------------ | -------------------- | -------: | --------------------------------------------- |
| `categoryId` | String (Document ID) |      Yes | Unique category identifier, e.g. `vegetables` |
| `name`       | String               |      Yes | Category name, e.g. `Rau củ`                  |
| `code`       | String               |      Yes | Category code, e.g. `VEGETABLES`              |
| `icon`       | String               |      Yes | Icon identifier                               |
| `isActive`   | Boolean              |      Yes | Whether category is active                    |
| `createdAt`  | Timestamp            |      Yes | Creation time                                 |
| `updatedAt`  | Timestamp            |      Yes | Last update                                   |

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

| Field       | Type          | Required | Description                                        |
| ----------- | ------------- | -------: | -------------------------------------------------- |
| `name`      | String        |      Yes | Household name, e.g. "My Home"                     |
| `ownerId`   | String        |      Yes | Reference to the owner's userId                    |
| `members`   | Array<String> |      Yes | Array of userIds who have access to this household |
| `createdAt` | Timestamp     |      Yes | Creation time                                      |
| `updatedAt` | Timestamp     |      Yes | Last update                                        |

---

# 9. Subcollection: inventory_items

**Path**

```text
households/{householdId}/inventory_items/{inventoryItemId}
```

| Field                 | Type      | Required | Description                                             |
| --------------------- | --------- | -------: | ------------------------------------------------------- |
| `foodId`              | String    |      Yes | Reference to food document ID                           |
| `name`                | String    |      Yes | Food name                                               |
| `quantity`            | Number    |      Yes | Purchase quantity                                       |
| `unit`                | String    |      Yes | Measurement unit                                        |
| `remainingPercentage` | Number    |      Yes | Remaining quantity percentage, from 0 to 100            |
| `storageLocationId`   | String    |      Yes | Reference to storage location document ID               |
| `purchaseDate`        | Timestamp |      Yes | Purchase date                                           |
| `expirationDate`      | Timestamp |      Yes | Expiration date                                         |
| `source`              | String    |      Yes | Source of inventory item, e.g. `manual`, `receipt_scan` |
| `createdAt`           | Timestamp |      Yes | Creation time                                           |
| `updatedAt`           | Timestamp |      Yes | Last update                                             |

---

# 10. Collection: shelf_life_rules

**Path**

```text
shelf_life_rules/{ruleId}
```

| Field               | Type      | Required | Description                                     |
| ------------------- | --------- | -------: | ----------------------------------------------- |
| `foodId`            | String    |      Yes | Reference to food document ID                   |
| `storageLocationId` | String    |      Yes | Reference to storage location document ID       |
| `minDays`           | Number    |      Yes | Minimum recommended storage days after purchase |
| `maxDays`           | Number    |      Yes | Maximum recommended storage days after purchase |
| `isActive`          | Boolean   |      Yes | Whether the rule is active                      |
| `createdAt`         | Timestamp |      Yes | Creation time                                   |
| `updatedAt`         | Timestamp |      Yes | Last update                                     |

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

| Field            | Type   | Required | Description                                                            |
| ---------------- | ------ | -------: | ---------------------------------------------------------------------- |
| `rawName`        | String |      Yes | Original product name extracted from the receipt by OCR                |
| `normalizedName` | String |      Yes | Standardized food name after text normalization                        |
| `foodId`         | String |       No | Reference to the matched food document ID                              |
| `quantity`       | Number |      Yes | Quantity of the food detected from the receipt                         |
| `unit`           | String |      Yes | Measurement unit, e.g. `kg`, `g`, `l`                                  |
| `confidence`     | Number |       No | Confidence score of the food recognition/matching result, if available |

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
    ├── foodId ────────────────→ foods
    └── storageLocationId ─────→ storage_locations


foods
└── categoryId ────────────────→ food_categories


shelf_life_rules
├── foodId ────────────────────→ foods
└── storageLocationId ────────→ storage_locations
```

---

# 19. Firebase Storage Structure

```text
Storage
│
├── users/
│   └── {userId}/
│       └── receipts/
│           └── {receiptId}/
│               └── {fileName}
│
└── foods/
    └── {foodId}/
        └── {fileName}
```

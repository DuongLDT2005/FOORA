# PLAN 05 – Chia sẻ household (mã mời 6 ký tự)

> Chức năng bổ sung trong `PRM393_Project.docx`: *"the owner generates a 6-character invite code, other members enter it to join
> and share the inventory and shopping list. The owner can view and remove members."*
> Hiện có: mỗi user có household mặc định (trigger `onUserCreated`), `households.members[]`, `verifyHouseholdAccess`,
> Rules chỉ cho member sửa `name`. 8 file stub trong `lib/features/household/`, `functions/src/household/index.ts` = `export {}`.
> Làm **trước** PLAN 01/04 vì shopping list và AI dùng chung household.

## 1. Công nghệ

Không cần thư viện mới.

| Phần | Công nghệ |
|---|---|
| Sinh mã | `crypto.randomInt` (Node built-in) – ngẫu nhiên an toàn, không dùng `Math.random` |
| Tham gia/xóa thành viên | Cloud Functions callable + Firestore transaction (Admin SDK) |
| Sao chép mã | `Clipboard.setData` (Flutter `services`, built-in) |
| Danh sách thành viên | Callable `getHouseholdMembers` (Rules không cho đọc doc `users` của người khác) |

## 2. Quyết định cần nhóm chốt trước khi code

| # | Câu hỏi | Đề xuất (mặc định nếu không chốt) | Lý do |
|---|---|---|---|
| D1 | `foodLimit` của household chung tính theo gói của ai? | **Gói của owner** | Kho thuộc household; nếu theo người thêm thì member Free sẽ bị chặn trong kho Premium của owner |
| D2 | Giới hạn số thành viên? | Không giới hạn theo gói (đề không có). Chỉ đặt **giới hạn kỹ thuật 20** (`MAX_HOUSEHOLD_MEMBERS`) để chống lạm dụng | Không tự thêm quyền lợi Premium |
| D3 | Thời hạn mã mời | 7 ngày, owner tạo lại bất cứ lúc nào (mã cũ hết hiệu lực) | Cân bằng tiện lợi/bảo mật |
| D4 | User đang ở household khác khi join | Được join; household cũ **giữ nguyên dữ liệu**, chỉ đổi `activeHouseholdId` | Không mất kho riêng |

Nếu chọn D1 = owner: sửa `InventoryService` dùng `MembershipService.resolveMembershipId(household.ownerId)` thay vì `user.membershipId`
(cả `addInventoryItemWithLimitCheck`, `writeBatchInTransaction`). Ghi vào DATABASE.md §8.

## 3. Data model

### 3.1 Collection server-only mới `household_invites/{code}`

| Field | Type | Mô tả |
|---|---|---|
| *(doc id)* | String | Mã 6 ký tự, viết hoa |
| `householdId` | String | |
| `createdBy` | String | uid owner |
| `isActive` | Boolean | `false` khi owner tạo mã mới/thu hồi |
| `expiresAt` | Timestamp | `createdAt + 7 ngày` |
| `useCount` | Number | số người đã join bằng mã |
| `createdAt` | Timestamp | |

Rules: `allow read, write: if false`.

### 3.2 Thêm vào `households/{householdId}` (backend ghi)

| Field | Type | Mô tả |
|---|---|---|
| `inviteCode` | String \| null | mã đang hiệu lực, để owner/member xem trên màn household |
| `inviteExpiresAt` | Timestamp \| null | |

Rules hiện tại chỉ cho client sửa `name`/`updatedAt` → hai field này tự động được bảo vệ.

### 3.3 Chống dò mã: `invite_attempts/{uid}` (server-only)

`{failedCount: number, windowStart: Timestamp}` – quá **10 lần sai trong 1 giờ** → `resource-exhausted` "Bạn nhập sai quá nhiều lần, thử lại sau 1 giờ".

### 3.4 Mã mời

- Bảng chữ: `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (bỏ `0 O 1 I L` dễ nhầm) → 31⁶ ≈ 887 triệu mã.
- `code = Array.from({length: 6}, () => ALPHABET[crypto.randomInt(ALPHABET.length)]).join("")`.
- Tạo bằng `transaction.create(inviteRef)`; trùng id → thử lại tối đa 5 lần.
- Input user: `trim().toUpperCase()`, bỏ khoảng trắng/gạch; validate regex `^[A-HJKMNP-Z2-9]{6}$`.

## 4. Backend – module `functions/src/household/`

```
household/
├── callables/
│   ├── create_household_invite.ts
│   ├── revoke_household_invite.ts
│   ├── join_household.ts
│   ├── leave_household.ts
│   ├── remove_household_member.ts
│   └── get_household_members.ts
├── services/
│   ├── household_service.ts      # transactions
│   ├── invite_code.ts            # pure: generate/normalize/validate
│   └── default_household.ts      # ensure user has own household (reuse auth_service logic)
└── index.ts
```
Thêm `Collections.HOUSEHOLD_INVITES`, `Collections.INVITE_ATTEMPTS`.
Mọi callable: `getAuthenticatedUser` đầu tiên; lỗi bằng helper `throw*` (return `never`).

### 4.1 `createHouseholdInvite({householdId})` → `{code, expiresAt}`
1. Household tồn tại, `ownerId == uid`, ngược lại `permission-denied`.
2. Transaction: nếu `household.inviteCode` → set invite cũ `isActive: false`; tạo invite mới; update household `inviteCode`, `inviteExpiresAt`.

### 4.2 `revokeHouseholdInvite({householdId})`
Owner only; invite hiện tại `isActive: false`; household `inviteCode: null`, `inviteExpiresAt: null`.

### 4.3 `joinHousehold({code})` → `{householdId, householdName}`
1. Kiểm tra `invite_attempts` (quá hạn mức → lỗi).
2. Transaction:
   - đọc invite: không tồn tại / `!isActive` / `expiresAt <= now` → tăng `failedCount` (ngoài transaction, sau khi rollback) và `not-found` "Mã mời không hợp lệ hoặc đã hết hạn".
   - đọc household: không tồn tại → `not-found`.
   - `members.includes(uid)` → chỉ set `activeHouseholdId` và trả về (idempotent).
   - `members.length >= MAX_HOUSEHOLD_MEMBERS` → `failed-precondition`.
   - update household `members: FieldValue.arrayUnion(uid)`, `updatedAt`; invite `useCount + 1`;
     update `users/{uid}.activeHouseholdId = householdId`.
   - tạo notification `system` cho owner: "{fullName} đã tham gia {householdName}".
3. Thành công → xóa `invite_attempts/{uid}`.

### 4.4 `leaveHousehold({householdId})`
- Owner không được rời household của mình (`failed-precondition` "Chủ nhà không thể rời; hãy xóa thành viên khác").
- Member: transaction `arrayRemove(uid)`; `activeHouseholdId` = household riêng của user (`DefaultHousehold.ensure(uid)` – tìm `households.where("ownerId","==",uid).limit(1)`, chưa có thì tạo mới giống `auth_service`: `name: "Tủ lạnh của {fullName}"`, `members: [uid]`, `activeItemCount: 0`).
- Inventory/shopping list do user đã thêm **ở lại** household chung (thuộc household).

### 4.5 `removeHouseholdMember({householdId, memberUid})`
Owner only, `memberUid != ownerId`, `memberUid ∈ members`. Giống leave cho member đó + notification `system` cho người bị xóa.

### 4.6 `getHouseholdMembers({householdId})` → `{members: [{uid, fullName, avatarUrl, isOwner}]}`
`verifyHouseholdAccess`; `db.getAll(...userRefs)`; **chỉ trả** `fullName`, `avatarUrl`, `isOwner` (không trả email).

### 4.7 Unit test
`invite_code.test.js`: độ dài/bảng chữ, normalize (" ab cd 2 3 " → "ABCD23"), validate từ chối `O/0/I/1/L`.
`household_service` với Firestore emulator (nếu nhóm có thời gian) hoặc test thủ công bảng ở mục 7.

## 5. Security Rules (cập nhật)

```
match /household_invites/{code} { allow read, write: if false; }
match /invite_attempts/{uid}   { allow read, write: if false; }
```
Giữ nguyên rules households hiện tại (member đọc, chỉ sửa `name`). Kiểm tra lại: member mới đọc được `inventory_items`/`shopping_list` qua `isHouseholdMember` → đúng ngay sau khi join.

## 6. Flutter – feature `lib/features/household/` (thay stub)

```
household/
├── domain/
│   ├── entities/household.dart            # add inviteCode, inviteExpiresAt
│   ├── entities/household_member.dart     # uid, fullName, avatarUrl, isOwner
│   ├── repositories/household_repository.dart
│   └── usecases/{watch_active_household.dart, create_invite.dart, revoke_invite.dart,
│                 join_household.dart, leave_household.dart, remove_member.dart,
│                 get_members.dart, rename_household.dart, validate_invite_code.dart}
├── data/
│   ├── models/{household_model.dart, household_member_model.dart}
│   ├── datasources/household_remote_datasource.dart   # stream households/{id}, callables
│   └── repositories/household_repository_impl.dart
└── presentation/
    ├── pages/household_page.dart
    ├── pages/join_household_page.dart
    ├── providers/household_provider.dart
    └── widgets/{member_list.dart, invite_dialog.dart, invite_code_card.dart}
```
Xóa stub cũ `get_current_household.dart`, `invite_member.dart`, `remove_member.dart` nếu không dùng tên đó; giữ nhất quán với danh sách trên.

Routes: `AppRouteNames.household = '/profile/household'`, `AppRouteNames.joinHousehold = '/profile/household/join'`.
Điểm vào: Profile menu "Gia đình của tôi".

### 6.1 Providers
- `activeHouseholdStreamProvider` – stream `households/{currentUser.activeHouseholdId}`.
- `householdMembersProvider` – `FutureProvider.autoDispose`, invalidate sau join/remove và khi `members.length` của stream đổi.
- `householdActionsControllerProvider` – `AsyncNotifier` cho các callable; map `Failure` → toast.

### 6.2 UI `HouseholdPage`
- Card thông tin: tên (owner/member đều sửa được – Rules đang cho phép; dialog sửa tên 1..100 ký tự), số món đang lưu (`activeItemCount`).
- `InviteCodeCard` (chỉ owner): mã to, font Lexend, chữ cách đều; "Hết hạn {dd/MM}"; nút **Sao chép** (`Clipboard.setData` + toast), **Tạo mã mới** (confirm dialog: mã cũ sẽ hết hiệu lực), **Thu hồi**. Chưa có mã → nút "Tạo mã mời".
- `MemberList`: avatar (`ProfileAvatar` có sẵn), tên, nhãn "Chủ nhà"; owner thấy nút xóa ở từng member (DialogHelper.showDeleteDialog).
- Member (không phải owner) thấy nút "Rời khỏi gia đình" (DangerButton + confirm).
- Nút "Tham gia gia đình khác" → `JoinHouseholdPage`.

### 6.3 UI `JoinHouseholdPage`
- 6 ô ký tự (một `TextField` ẩn + 6 box hiển thị), `textCapitalization: characters`, input formatter lọc ký tự ngoài bảng chữ, tự upper-case.
- Nút "Tham gia" enable khi đủ 6 ký tự hợp lệ (`ValidateInviteCode` use case).
- Nếu user đang có món trong household hiện tại → dialog cảnh báo "Kho hiện tại sẽ được giữ nguyên nhưng bạn sẽ chuyển sang dùng kho của gia đình mới".
- Thành công → toast "Đã tham gia {name}", `context.go(AppRouteNames.home)`.

### 6.4 Ảnh hưởng tới phần đã có (kiểm tra sau khi làm)
- Inventory/Home/Expiration đọc theo `activeHouseholdId` từ `currentUserProvider` (stream user doc) → tự đổi kho khi join/leave. Kiểm tra các provider `autoDispose`/`family` không giữ householdId cũ.
- `checkExpiryDailyCron` (hoặc `hourlyReminderCron` PLAN 02) đã fan-out theo `memberIds` → thành viên mới nhận thông báo hạn dùng.
- Membership page: "Số lượng thực phẩm" hiển thị theo gói **owner** nếu chọn D1.

## 7. Test

- Unit Flutter: `ValidateInviteCode`, `HouseholdModel` parse `inviteCode`.
- Widget: owner thấy `InviteCodeCard` + nút xóa member; member không thấy; join page disable nút khi < 6 ký tự.
- Thủ công 2 tài khoản trên emulator/máy thật:
  1. A tạo mã → B join → B thấy kho A realtime, A nhận notification.
  2. B thêm món → A thấy ngay; `activeItemCount` tăng.
  3. A xóa B → B về kho riêng, nhận notification; B không đọc được kho A (thử query → permission-denied).
  4. Mã hết hạn/thu hồi → B nhận "Mã mời không hợp lệ".
  5. Nhập sai 11 lần → bị khóa 1 giờ.

## 8. Cập nhật tài liệu
- DATABASE.md: `household_invites`, `invite_attempts`, field mới của households, quyết định D1–D4.
- FUNCTIONS_GUIDE.md: 6 callable (thay `createHousehold`/`joinHousehold` trong bảng cũ).
- `firestore.rules`.

## 9. Definition of Done
- [ ] Owner tạo/sao chép/tạo lại/thu hồi mã; mã hết hạn sau 7 ngày.
- [ ] Member join bằng mã, dùng chung inventory + shopping list realtime.
- [ ] Owner xem danh sách (tên, avatar) và xóa member; member rời được; ai rời/bị xóa quay về kho riêng.
- [ ] Không thể đọc kho của household không tham gia; không dò được mã (giới hạn sai).

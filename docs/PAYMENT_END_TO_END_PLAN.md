# FOORA Payment End-to-End Plan

## Trang thai implementation

Da hoan thanh trong repo:

- Backend core: create/cancel order, Cas client adapter, webhook V2 signature,
  reconciliation/idempotency, order lock, Premium activation va expiry scheduler.
- Firestore Rules/indexes va data/functions contract.
- Flutter data/domain/controller, realtime watcher, routing, QR/result/history UI.
- Backward-compatible mapping cho payment IAP cu.
- Functions build/lint/unit tests, Flutter analyze va payment unit/widget tests.

Con phu thuoc dau vao ben ngoai:

- Xac nhan schema request/response `/qr-pay` voi Cas merchant account thuc te.
- Merchant grant/onboarding va Firebase secrets cua sandbox/production.
- Stitch project/screen IDs de visual diff/golden sign-off.
- Sandbox E2E va Rules emulator integration test.


## 1. Muc tieu va gia dinh

Xay dung luong nang cap FOORA Premium hoan chinh, trong do:

- UI Flutter khop voi cac man hinh Payment tren Stitch.
- Cong thanh toan dung **Cas QR Pay**; **Cas ID chi duoc dung trong merchant onboarding**.
- Flutter khong giu khoa bi mat va khong tu xac nhan thanh toan.
- Cloud Functions tao don, tao QR, nhan webhook, doi soat va kich hoat Premium.
- Tat ca thao tac ghi `payments`, `subscriptions` va `users.membershipId` chi do backend thuc hien.

Gia dinh cua plan: "CAS ID" trong yeu cau la **Cas ID cua Cas/Casso**. Cas ID chi duoc FOORA Admin/merchant dung mot lan de lien ket tai khoan ngan hang voi Cas. End user va household khong dang nhap, khong lien ket va khong can co Cas ID de mua Premium; ho chi quet ma QR Pay bang app ngan hang.

### Quyet dinh kien truc da chot

- **FOORA la merchant duy nhat** va nhan tien vao tai khoan merchant cua FOORA.
- Household/user la customer mua Premium, khong phai merchant va khong co Cas grant rieng.
- Payment status thanh cong duy nhat la `completed`; khong dung `paid` trong domain, Firestore hay UI state.
- `subscriptions` la source of truth cua quyen Premium. `payments` la bang chung giao dich; `users.membershipId` chi la derived cache de hien thi/truy van nhanh.
- Payment sau khi bi cancel hoac thanh toan thuc te sau han khong tu dong kich hoat Premium; no chuyen sang `requires_review` de doi soat thu cong.

## 2. Dau vao bat buoc truoc khi code

### Stitch design contract

Can chot cac thong tin sau trong ticket implementation:

- Stitch project ID va screen ID cua: chon goi, xac nhan thanh toan, QR thanh toan, thanh cong, that bai/het han, lich su giao dich.
- Export anh tham chieu o kich thuoc goc va ghi lai viewport cua tung screen.
- Token giao dien: mau, typography, spacing, radius, shadow, icon va asset.
- Cac state khong co tren happy-path: loading, retry, QR expired, webhook pending, duplicate tap, offline va payment failed.

Quy tac UI:

- Stitch la source of truth cho bo cuc va visual; khong tu thiet ke lai.
- Map token Stitch vao `AppColors`, typography hien co, `ScreenUtil`, `AppHeader` va `SubpageLayout` cua repo.
- Dung icon library hien co; khong ve SVG moi neu da co icon tuong ung.
- So sanh screenshot implementation voi Stitch tren cung viewport. Sai le visual phai duoc xu ly truoc khi dong phase UI.

### Cas credentials va merchant onboarding

Can co tai khoan Cas va hai bo credential rieng:

- Sandbox: `CAS_CLIENT_ID`, `CAS_SECRET_KEY`, `CAS_BASE_URL=https://sandbox.bankhub.dev`.
- Production: credential production va `CAS_BASE_URL=https://production.bankhub.dev`.
- Webhook signing secret hoac co che xac thuc webhook theo contract duoc cap cho merchant.
- Redirect/deep-link URI cho Cas Link.

Secret phai nam trong Firebase Secret Manager. Khong dua `x-secret-key` hoac access token vao Flutter, `.env` client, Git hay Firestore ma client doc duoc.

Merchant onboarding la luong quan tri mot lan cua **FOORA Admin**, tach khoi luong mua Premium cua user:

1. Backend tao grant token voi scope `qrpay`.
2. FOORA Admin mo Cas Link va xac thuc bang Cas ID.
3. Client nhan `publicToken` va gui ngay ve backend.
4. Backend exchange thanh `accessToken`/`grantId`, kiem tra QR Pay identity.
5. Backend ma hoa va luu mot merchant grant server-side; man hinh quan tri chi nhan trang thai `connected`.

Flutter cua end user khong nhan `grantToken`, `publicToken`, `accessToken` va khong mo Cas Link. Luong thanh toan end user bat dau truc tiep tu callable tao QR Pay bang merchant grant cua FOORA.

## 3. Pham vi MVP

Trong MVP:

- Mot goi Premium va mot chu ky thanh toan co dinh.
- Tien te VND, gia lay tu `memberships/{membershipId}` tren server.
- Tao QR dong theo tung order qua Cas QR Pay.
- Theo doi trang thai realtime: `pending -> completed | expired | failed | cancelled | requires_review`.
- Kich hoat subscription sau webhook hop le.
- Lich su giao dich cua user.
- Retry an toan va idempotency cho callable/webhook.
- Sandbox va emulator test.

Ngoai MVP:

- Auto debit/tu dong gia han.
- Refund tu dong.
- Coupon, VAT invoice, nhieu currency.
- Admin dashboard day du; MVP chi can merchant connection status va log doi soat toi thieu.

Luu y: QR Pay la bank transfer theo don, khong mac dinh co auto-renew. Subscription nen de `autoRenew=false` va user thanh toan lai khi het han, tru khi ky hop dong them san pham Auto Debit.

## 4. Luong end-to-end

```text
User chon Premium
  -> Flutter goi createCasPaymentOrder(membershipId)
  -> Cloud Functions doc gia/goi tu Firestore
  -> Tao payment pending + referenceNumber duy nhat
  -> Goi Cas POST /qr-pay
  -> Luu requestId, QR payload, expiresAt
  -> Flutter hien QR va lang nghe payment document
  -> User quet QR bang app ngan hang
  -> Cas gui webhook TRANSACTIONS
  -> Backend xac thuc webhook + tim referenceNumber
  -> Doi soat amount/currency/order/user va chong trung
  -> Firestore transaction: payment=completed, subscription=active,
     user.membershipId=premium
  -> Flutter nhan snapshot completed va hien success theo Stitch
```

Khong danh dau thanh cong dua tren nut "Toi da thanh toan", deep link quay lai app, anh chup bien lai, noi dung chuyen khoan do client gui, hay polling tu client ma khong co ket qua doi soat server-side.

## 5. Data model va migration

Schema hien tai trong `DATABASE.md` dang mo ta IAP (`android/ios`, `productId`, `purchaseToken`). Can migration tai lieu va model truoc khi implement Cas.

### `users/{uid}/payments/{paymentId}`

Toi thieu:

| Field | Type | Noi dung |
| --- | --- | --- |
| `membershipId` | String | Goi mua, vi du `premium` |
| `subscriptionId` | String? | Co sau khi thanh toan thanh cong |
| `provider` | String | `cas_qr_pay` |
| `providerRequestId` | String? | `requestId` tu Cas |
| `referenceNumber` | String | Ma order noi bo, unique va khong chua PII |
| `providerTransactionId` | String? | ID giao dich tu webhook |
| `amount` | Number | Gia server da snapshot |
| `currency` | String | `VND` |
| `status` | String | `pending`, `completed`, `failed`, `expired`, `cancelled`, `requires_review` |
| `qrCode` | String? | Payload QR; xoa/khong tra sau khi het han neu can |
| `virtualAccountNumber` | String? | Tai khoan ao Cas tra ve |
| `description` | String | Noi dung thanh toan da tao |
| `expiresAt` | Timestamp | Han thanh toan |
| `paidAt` | Timestamp? | Thoi diem giao dich do provider xac nhan |
| `cancelledAt` | Timestamp? | Thoi diem user/backend huy order pending |
| `reviewReason` | String? | `paid_after_expiry` hoac `paid_after_cancel` |
| `createdAt`, `updatedAt` | Timestamp | Audit timestamps |

Khong luu raw access token, secret, full webhook payload hoac thong tin ngan hang nhay cam trong document user co the doc.

### `users/{uid}/subscriptions/{subscriptionId}`

- Doi `platform` thanh `provider: cas_qr_pay` hoac mo rong enum platform de co `cas`.
- `productId` co the doi thanh `planId`; neu giu de tuong thich, map bang `membershipId`/billing period noi bo.
- `autoRenew=false`, `cancelAtPeriodEnd=false` cho QR Pay MVP.
- `startDate` la thoi diem webhook duoc xac nhan; `endDate` tinh tu duration cua plan tren server.
- Neu user dang Premium va mua them, quy tac gia han: `startDate = max(now, currentEndDate)`; khong rut ngan thoi han hien tai.

### Source of truth cho Premium

Quyen Premium phai duoc resolve tu subscription hop le:

```text
status == active
AND startDate <= serverNow
AND endDate > serverNow
```

- `payments.status=completed` chi chung minh giao dich da doi soat, khong tu no cap quyen truy cap.
- `users.membershipId` la derived cache duoc backend dong bo trong cung Firestore transaction khi activate/expire subscription. Logic phan quyen khong duoc chi tin field nay.
- Neu co nhieu subscription, entitlement resolver chon subscription active co `endDate` xa nhat.
- Scheduler subscription expiry chuyen `active -> expired`, sau do recompute `users.membershipId`; chi downgrade ve `free` khi khong con subscription Premium active nao.
- Membership/quota service phai dung chung mot entitlement resolver de tranh moi module tu dien giai subscription theo cach khac nhau.

### Server-only payment index

Tao collection backend-only de tim webhook nhanh va enforce uniqueness:

```text
payment_references/{referenceNumber}
```

Document chua `uid`, `paymentId`, expected amount, status va provider. Firestore Rules chan toan bo client read/write. Day la index doi soat, khong phai source of truth hien thi UI.

## 6. Backend Cloud Functions

De xuat cau truc:

```text
functions/src/payment/
  callables/
    create_cas_payment_order.ts
    cancel_cas_payment_order.ts
    get_cas_connection_status.ts
  webhooks/
    cas_transactions_webhook.ts
  services/
    cas_client.ts
    cas_grant_service.ts
    payment_order_service.ts
    payment_reconciliation_service.ts
    subscription_activation_service.ts
  types/
    cas_contracts.ts
    payment_contracts.ts
  index.ts
```

### `createCasPaymentOrder`

Input: `{ membershipId: string }`.

Server phai:

1. Xac thuc Firebase user va `isActive`.
2. Doc membership active, amount va duration tu Firestore; bo qua gia tu client.
3. Reuse order `pending` chua het han cho cung user/goi de tranh tao QR trung khi double tap.
4. Tao `paymentId` va `referenceNumber` ngau nhien, duy nhat.
5. Ghi payment `pending` va payment reference.
6. Goi Cas `POST /qr-pay` voi amount, description, referenceNumber.
7. Cap nhat QR response va `expiresAt`.
8. Tra DTO chi gom field UI can: paymentId, amount, currency, qrCode, account display data, description, expiresAt.

Neu Cas API loi sau khi da tao payment, cap nhat `failed` voi ma loi da sanitize; khong tra secret/raw provider response cho client.

### `casTransactionsWebhook`

Webhook HTTP phai:

1. Chi nhan `POST`, gioi han content type/body size va rate limit tai ingress neu co.
2. Xac thuc chu ky/token/source theo contract Cas production. Neu Cas khong cap signature, dung URL secret xoay vong, App Check/WAF khong thay the duoc provider authentication.
3. Parse event `TRANSACTIONS`; lay `paymentMeta.referenceNumber`.
4. Tim `payment_references/{referenceNumber}` va payment goc.
5. Kiem tra provider transaction ID chua duoc xu ly, amount chinh xac, giao dich incoming, dung reference; so sanh provider transaction time voi `expiresAt`/`cancelledAt` de phan loai completed hay requires_review.
6. Neu du dieu kien, chay mot Firestore transaction de ghi payment completed, tao/gia han subscription active va cap nhat derived cache `users/{uid}.membershipId='premium'`.
7. Ghi event ID vao inbox/idempotency store truoc khi tra `2xx`.
8. Tra `2xx` cho event da xu ly truoc do; tra loi phu hop de Cas retry voi loi tam thoi.

Khong log secret, access token, full account number hoac payload co PII. Log co cau truc voi `eventId`, `referenceNumber`, `paymentId`, ket qua va error code.

### State machine: cancel, expired va late payment

Chi cac transition sau la hop le:

```text
pending -> completed
pending -> failed
pending -> cancelled
pending -> expired
cancelled -> completed           (da chuyen tien truoc luc cancel, webhook den tre)
cancelled -> requires_review     (chuyen tien thuc te sau luc cancel)
expired -> completed             (da chuyen tien truoc han, webhook den tre)
expired -> requires_review       (chuyen tien thuc te sau han)
```

- **Cancel**: chi cho phep khi payment dang `pending`. Cancel dong nghia user tu bo order trong FOORA; khong co nghia ma QR chac chan khong the nhan tien nua. Backend ghi `cancelledAt` theo server time. `completed`, `failed` va `requires_review` khong cancel duoc.
- **Expired**: scheduler chuyen `pending -> expired` khi `serverNow > expiresAt`. Expired dong man hinh cho thanh toan va khong tu dong cap Premium.
- **Webhook den tre**: phan loai theo thoi diem giao dich cua provider, khong theo thoi diem webhook toi server. Neu giao dich xay ra truoc hoac dung `expiresAt` va truoc hoac dung `cancelledAt` (neu co), backend van chuyen sang `completed` du webhook den sau.
- **Late payment**: giao dich xay ra sau `expiresAt`, hoac sau `cancelledAt`, chuyen payment sang `requires_review`, ghi `paidAt` va `reviewReason`, tao admin alert va khong activate subscription.
- Admin sau doi soat chi duoc chon mot trong hai hanh dong co audit: accept thanh `completed` va activate subscription, hoac ghi nhan refund/reject theo runbook.
- Race giua cancel/expiry/webhook phai duoc xu ly trong Firestore transaction voi precondition tren status va timestamps.
- Job doi soat dinh ky co the dung API transactions cua Cas de phuc hoi webhook bi mat, nhung chi la lop bo sung, khong thay the webhook.
- UI coi `completed` la thanh cong; `requires_review` hien thong bao dang doi soat, khong hien thanh cong.

### Config va export

- Them Firebase secrets cho client ID, secret key, encrypted grant/access token va webhook secret.
- Export callables/webhook tu `functions/src/payment/index.ts` va root `functions/src/index.ts` theo convention repo.
- Region cua callable va webhook theo `REGION` hien co; webhook URL production phai duoc dang ky trong Cas Console.

## 7. Flutter architecture

### Domain

- Mo rong `PaymentTransaction` cho provider, reference, expiry va status Cas.
- `PaymentRepository`:
  - `createPaymentOrder(membershipId)`
  - `watchPayment(paymentId)`
  - `getPaymentHistory()`
  - `cancelPendingPayment(paymentId)`
- Use cases tuong ung; khong dua Firebase/Cas DTO vao presentation.

### Data

- `PaymentRemoteDatasource` goi Firebase Callable de tao/huy order.
- Firestore datasource watch `users/{uid}/payments/{paymentId}` va query history.
- Model parse timestamp/status theo `AppEnums`, co fallback ro rang cho backward compatibility.
- Flutter khong goi truc tiep `bankhub.dev` va khong chua Cas secret.

### Presentation state

`PaymentProvider`/controller quan ly cac state co kieu:

- `idle`
- `creatingOrder`
- `awaitingPayment(order)`
- `verifying(order)`
- `completed(transaction)`
- `expired(order)`
- `cancelled(order)`
- `requiresReview(order)`
- `failed(message, retryable)`

Controller huy Firestore subscription khi dispose, khoa double submit, giu cung payment pending khi app resume va khong tu set completed.

## 8. UI theo Stitch

Implement cac man hinh/thanh phan sau sau khi da chot Stitch IDs:

- `membership_page.dart`: goi, gia, quyen loi, CTA.
- `payment_page.dart`: tong don va phuong thuc Cas QR Pay.
- `payment_qr_page.dart`: QR, amount, countdown, copy noi dung/STK, trang thai dang cho.
- `payment_result_page.dart`: success, failed, expired, cancelled, requires-review va CTA tuong ung.
- `payment_history_page.dart`: danh sach, empty/loading/error, chi tiet giao dich.
- `payment_method_selector.dart`: chi hien neu Stitch co buoc chon phuong thuc; MVP co mot phuong thuc thi khong tao interaction thua.

Routing:

- Thay placeholder `/membership` va `/payment-history` trong `app_router.dart`.
- Them route payment QR/result voi `paymentId`; khong truyen secret hay toan bo payment object trong URL.
- Deep link/app resume quay lai payment hien tai va tiep tuc watch Firestore.

Visual verification gate:

1. Render tung state tren dung viewport cua Stitch.
2. Chup screenshot/golden cho light mode va cac kich thuoc mobile duoc ho tro.
3. Overlay/diff voi anh Stitch, sua spacing, font, mau, radius va asset.
4. Kiem tra text scaling, ten ngan hang/noi dung dai, keyboard, safe area va overflow.
5. Chi dong UI khi cac state loading/pending/success/error cung dat, khong chi happy-path.

## 9. Security va Firestore Rules

- User chi duoc doc payment/subscription cua chinh minh.
- Client khong duoc create/update/delete payment, subscription, payment reference hay merchant grant.
- Admin access dung custom claims hien co, khong tin field role do client gui.
- Callable bat buoc Firebase Auth; bat App Check khi app san sang production.
- Gia, duration, membershipId hop le, entitlement va status transition deu do server quyet dinh.
- Reference number khong chua uid/email/phone va khong duoc dung nhu authentication secret.
- Them retention policy cho payment logs va webhook inbox.

## 10. Test plan

### Backend unit/integration

- Tao order thanh cong va reuse pending order.
- Membership khong ton tai/inactive, user bi khoa, Cas timeout/4xx/5xx.
- Webhook hop le kich hoat Premium dung mot lan.
- Duplicate webhook, duplicate provider transaction, sai amount, sai reference, outgoing transaction, payment expired.
- Cancel/webhook race; payment dung han nhung webhook den tre; payment thuc te sau expiry/cancel phai vao `requires_review`.
- Gia han khi subscription dang active va khi da expired.
- Entitlement chi active theo subscription; cache `users.membershipId` duoc recompute dung khi subscription het han.
- Firestore transaction rollback neu mot write loi.
- Scheduled expiry va reconciliation.
- Rules emulator chung minh client khong ghi duoc protected collections.

Cas client phai inject duoc fake transport de test, khong goi sandbox trong unit test.

### Flutter unit/widget

- Model mapping cho schema cu va moi.
- Controller state transitions, retry, dispose va app resume.
- Widget test cho tat ca state UI va CTA.
- Countdown khong am; QR/chu dai khong overflow.
- Golden/screenshot test cho cac Stitch reference screen.

### End-to-end sandbox

1. Merchant sandbox grant connected.
2. User tao QR tu app.
3. Thanh toan sandbox hoac replay fixture webhook da ky/xac thuc.
4. Payment doi sang completed dung mot lan.
5. Subscription va membership cap nhat atomically.
6. App dang mo va app resume deu den success screen.
7. Payment xuat hien dung trong history.

## 11. Thu tu implementation

### Phase 0 - Chot contract

- Gan Stitch project/screen IDs vao ticket.
- Chot goi, gia, duration, expiry va late-payment review policy.
- Tao Cas sandbox app, webhook va merchant grant.
- Cap nhat `DATABASE.md`, `FUNCTIONS_GUIDE.md`, enums va acceptance fixtures.

Deliverable: design/API/data contract duoc review, khong con placeholder quan trong.

### Phase 1 - Backend payment core

- Cas client, secret config, create order, data migration.
- Webhook authentication, reconciliation va idempotent activation.
- Expiry scheduler, structured logs, emulator tests va Rules.

Deliverable: co the hoan tat mot thanh toan sandbox khong can Flutter UI.

### Phase 2 - Flutter data/domain

- Entity/model/repository/datasource/use cases/controller.
- Routing va realtime payment watcher.
- Unit tests.

Deliverable: flow chay bang UI toi thieu va fake/sandbox backend.

### Phase 3 - Stitch UI

- Implement day du screen/state theo Stitch.
- Responsive, accessibility, localization neu repo bat buoc.
- Widget/golden tests va screenshot comparison.

Deliverable: visual sign-off theo tung Stitch screen ID.

### Phase 4 - Hardening va release

- E2E sandbox, webhook retry/late payment/runbook.
- Production credentials, webhook URL va monitoring/alerts.
- Smoke test gia tri nho theo quy trinh duoc phe duyet.
- Rollback/disable switch cho tao order moi, khong lam mat webhook dang den.

Deliverable: production readiness checklist duoc ky duyet.

## 12. Definition of Done

- UI khop Stitch o tat ca screen va state da thong nhat, co screenshot/golden evidence.
- Khong co Cas secret/token trong app bundle, Git, log hoac client-readable Firestore.
- Client khong the tu nang membership hay sua payment status.
- Moi kiem tra quyen Premium dung subscription active lam source of truth; `users.membershipId` chi la derived cache.
- Webhook duplicate/retry khong tao trung subscription va khong gia han hai lan.
- Amount/reference/provider transaction duoc doi soat server-side.
- Payment history hien dung `pending/completed/failed/expired/cancelled/requires_review`.
- `flutter analyze`, Flutter tests, Functions lint/build/tests va Rules tests deu pass.
- Sandbox E2E pass; monitoring va runbook late payment/webhook failure da co.

## 13. Cac quyet dinh can chot

- Stitch project ID va danh sach screen ID cu the.
- Mot goi thang hay them nam; gia va thoi han tung goi.
- QR het han sau bao lau; nguong nay la contract de phan loai late payment.
- Cho phep gia han som hay chan mua khi Premium con han.
- Cas cung cap co che xac thuc webhook nao cho tai khoan production.
- Refund/chargeback xu ly thu cong hay can phase sau.

## 14. Tai lieu provider tham chieu

- Cas Quickstart: grant token, Cas Link, token exchange va environments.
- Cas QR Pay: tao QR theo `referenceNumber` va nhan webhook `TRANSACTIONS`.
- Cas API Reference: headers `x-client-id`, `x-secret-key`, `Authorization` va endpoint `/qr-pay`.

Khi bat dau implementation, phai doi chieu lai API schema va webhook authentication voi tai lieu Cas hien hanh; khong suy doan field provider tu plan nay.

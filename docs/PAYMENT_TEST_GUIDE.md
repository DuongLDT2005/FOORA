# FOORA Payment - Huong dan test

Tai lieu nay dung de test feature payment da implement trong repo. Luu y: ten
callable/webhook hien van giu `createCasPaymentOrder`,
`cancelCasPaymentOrder`, `casTransactionsWebhook` de tuong thich routing cu,
nhung provider thuc te trong code hien tai la `payos`.

Production deployment va smoke test tien that do Tech Lead/DevOps thuc hien.
Developer/QA uu tien test tren Firebase Emulator va Android/Web local.

## 1. Pham vi can test

Payment flow hien co gom:

- Tao payment order Premium bang callable `createCasPaymentOrder`.
- Backend lay gia/thoi han tu `memberships/premium`, khong tin gia tu client.
- Goi payOS tao QR, luu payment `pending`, `referenceNumber`, `qrCode`,
  `providerRequestId`, `expiresAt`.
- Reuse order `pending` con han khi user bam tao QR lap lai.
- Huy order bang callable `cancelCasPaymentOrder`.
- Nhan webhook payOS qua `casTransactionsWebhook`, verify signature bang
  `PAYOS_CHECKSUM_KEY`, doi soat amount/reference/transaction id.
- Kich hoat Premium khi payment `completed`.
- Dua payment vao `requires_review` khi sai amount hoac late payment.
- Scheduler `expirePendingPayments` chuyen payment qua han sang `expired` va
  subscription het han sang `expired`.
- Flutter hien man xac nhan, QR, ket qua va lich su payment.

## 2. Dieu kien truoc khi test

Can co dependencies:

```powershell
flutter pub get

Push-Location functions
npm install
Pop-Location
```

Can co file local:

- `.env.local.json` cho Flutter local emulator.
- `functions/.secret.local` co cac secret payOS.
- Neu chua co secret sandbox that, van co the chay unit tests. De tao QR that
  qua provider, phai co credential payOS hop le.

Gia tri secret can thiet:

```dotenv
PAYOS_CLIENT_ID=<payos-client-id>
PAYOS_API_KEY=<payos-api-key>
PAYOS_CHECKSUM_KEY=<payos-checksum-key>
```

Non-secret config co default trong code:

```dotenv
PAYOS_BASE_URL=https://api-merchant.payos.vn
PAYOS_RETURN_URL=https://foora.app/payment/success
PAYOS_CANCEL_URL=https://foora.app/payment/cancel
PAYMENT_EXPIRY_MINUTES=15
```

Khong commit secret, URL webhook private, payload ngan hang that, hoac thong tin
tai khoan merchant vao Git.

## 3. Quality gate tu dong

Chay tu root repo:

```powershell
Push-Location functions
npm run lint
npm test
Pop-Location

flutter analyze
flutter test test/features/payment
```

Neu muon chay test Flutter rong hon:

```powershell
flutter test
```

Ky vong:

- `npm test` pass cac test payOS client va webhook parser.
- `flutter analyze` khong co error.
- Payment unit/widget tests pass.
- Neu full Flutter suite fail vi fixture ngoai payment, ghi ro test nao ngoai
  pham vi va van phai dam bao payment tests pass.

## 4. Chay local emulator

Mo 4 terminal rieng.

Terminal 1, build watch Functions:

```powershell
Set-Location functions
npm run build:watch
```

Terminal 2, Firebase Emulator:

```powershell
firebase emulators:start --project foora-app
```

Port mac dinh:

- Emulator UI: http://localhost:4000
- Auth: 9099
- Functions: 5001
- Firestore: 8080
- Storage: 9199

Terminal 3, seed du lieu:

```powershell
Set-Location functions
npm run seed:emulator
```

Tai khoan test:

- Free user: `user.free@gmail.com` / `Password@123`
- Premium user: `user.premium@gmail.com` / `Password@123`
- Admin: `foora.team@gmail.com` / `Password@123`

Seed quan trong:

- `memberships/premium`: price `29000`, currency `VND`, duration `30` ngay.
- Premium seeded subscription: `users/{uid}/subscriptions/payos_premium`.

Terminal 4, Flutter:

```powershell
flutter devices
flutter run -d <device-id> --dart-define-from-file=.env.local.json
```

Voi Web:

```powershell
flutter run -d chrome --dart-define-from-file=.env.local.json
```

## 5. Smoke test UI

Dang nhap `user.free@gmail.com`.

1. Mo Profile > Goi thanh vien.
2. Chon nang cap Premium.
3. Kiem tra man xac nhan payment:
   - Goi Premium hien dung ten/goi.
   - Gia hien `29.000 VND` hoac format tuong duong.
   - Phuong thuc hien `payOS`.
   - Text tieng Viet khong bi loi encoding.
4. Bam tao QR.
5. Kiem tra man QR:
   - Co QR render duoc.
   - Co so tien, noi dung chuyen khoan, ma tham chieu.
   - Countdown khong am.
   - Nut copy copy dung gia tri.
   - Nut huy giao dich hien va khong gay crash.
6. Vao Emulator UI, mo:
   - `users/{uid}/payments/{paymentId}`
   - `payment_references/{referenceNumber}`

Ky vong Firestore sau khi tao order:

- Payment `status = pending`.
- `provider = payos`.
- `amount = 29000`.
- `currency = VND`.
- `referenceNumber` la so, trung voi `payment_references` document id.
- `description = FOORA <referenceNumber>`.
- `qrCode` khong rong.
- `expiresAt` lon hon thoi diem tao.
- `payment_references/{referenceNumber}.status = pending`.

## 6. Test completed bang webhook replay local

Lay `referenceNumber` tu payment document, vi du `123456789012`.

Chay:

```powershell
.\scripts\replay_cas_webhook.ps1 `
  -ReferenceNumber "123456789012" `
  -TransactionId "local-e2e-001"
```

Script nay dang giu ten `cas` vi lich su file, nhung payload va signature la
payOS. Script doc `PAYOS_CHECKSUM_KEY` tu `functions/.secret.local` va goi:

```text
http://127.0.0.1:5001/foora-app/asia-southeast1/casTransactionsWebhook
```

Response ky vong:

```json
{
  "success": true,
  "status": "completed"
}
```

Kiem tra Firestore:

- Payment `status = completed`.
- `providerTransactionId = local-e2e-001`.
- `paidAt` duoc set.
- `subscriptionId = payos_premium`.
- `users/{uid}/subscriptions/payos_premium.status = active`.
- `lastPaymentId` bang payment vua tao.
- `autoRenew = false`.
- `cancelAtPeriodEnd = false`.
- `users/{uid}.membershipId = premium`.
- `payment_provider_transactions/local-e2e-001` ton tai.
- `payment_references/{referenceNumber}.status = completed`.

Kiem tra app:

- Neu dang o man QR, app tu chuyen sang result success.
- Mo lai app hoac reload web, result/history van hien completed.
- Payment history co giao dich vua tao.

## 7. Test idempotency

Chay lai dung webhook voi cung `TransactionId`:

```powershell
.\scripts\replay_cas_webhook.ps1 `
  -ReferenceNumber "123456789012" `
  -TransactionId "local-e2e-001"
```

Ky vong:

- Response van `200` va status hien tai la `completed`.
- Khong co provider transaction thu hai cho cung transaction id.
- Subscription `endDate` khong bi cong them lan hai.
- `lastPaymentId` khong doi bat thuong.

## 8. Test sai amount

Tao payment moi, lay `referenceNumber` moi, sau do replay amount sai:

```powershell
.\scripts\replay_cas_webhook.ps1 `
  -ReferenceNumber "<reference-moi>" `
  -Amount 28000 `
  -TransactionId "local-wrong-amount-001"
```

Ky vong:

- Payment `status = requires_review`.
- `reviewReason = amount_mismatch`.
- `paidAt` va `providerTransactionId` duoc ghi.
- Khong activate/gia han subscription.
- `users/{uid}.membershipId` khong chuyen sang Premium neu truoc do la Free.
- UI result hien trang thai doi soat, khong hien thanh cong.

## 9. Test late payment sau expiry

Tao payment moi, lay `expiresAt` trong Emulator UI. Replay voi
`TransactionDateTime` muon hon `expiresAt`:

```powershell
.\scripts\replay_cas_webhook.ps1 `
  -ReferenceNumber "<reference-moi>" `
  -TransactionId "local-late-001" `
  -TransactionDateTime "2026-09-26 10:00:00"
```

Chon timestamp chac chan sau `expiresAt` cua payment dang test.

Ky vong:

- Payment `status = requires_review`.
- `reviewReason = late_payment`.
- Khong activate/gia han subscription.
- UI result hien doi soat.

## 10. Test huy payment

Tao payment moi, khi con `pending`:

1. O man QR, bam `Huy giao dich`.
2. Doi Firestore snapshot update.

Ky vong:

- Payment `status = cancelled`.
- `cancelledAt` duoc set.
- `payment_references/{referenceNumber}.status = cancelled`.
- UI tu chuyen sang result cancelled.
- Khong activate subscription.

Can test them:

- Bam huy lai lan hai khong crash.
- Replay webhook co `TransactionDateTime` sau `cancelledAt` thi payment vao
  `requires_review`.
- Replay webhook co `TransactionDateTime` truoc hoac bang `cancelledAt` co the
  completed theo logic backend, vi tien da chuyen truoc luc cancel.

## 11. Test expiry

Cach nhanh nhat tren local:

1. Dat `PAYMENT_EXPIRY_MINUTES=1` trong config local Functions neu moi truong
   cua ban dang load bien nay.
2. Restart Functions emulator.
3. Tao payment moi va doi qua han.
4. Cho scheduled function chay, hoac trigger schedule theo cach emulator ho tro.

Ky vong:

- Payment `pending` qua han thanh `expired`.
- `payment_references/{referenceNumber}.status = expired`.
- UI result hien expired.
- Khong activate subscription.

Neu khong trigger duoc scheduled function trong emulator, co the verify logic bang
unit/integration test hoac tam thoi sua `expiresAt` tren emulator roi chay
function schedule trong Functions shell. Khong sua production data de test expiry.

## 12. Test reuse pending order

1. Tao order Premium thanh cong.
2. Quay lai man xac nhan va bam tao QR them lan nua truoc khi order het han.

Ky vong:

- Backend tra lai cung `paymentId`.
- Khong tao payment pending moi cho cung user/goi khi lock con hop le.
- UI vao lai dung QR/reference dang pending.

## 13. Test access control Firestore

Tren app/client:

- User chi doc duoc `users/{ownUid}/payments`.
- Client khong tu create/update/delete payment.
- Client khong doc/ghi duoc `payment_references`.
- Client khong doc/ghi duoc `payment_provider_transactions`.
- Client khong tu tao/sua subscription de nang Premium.

Neu co Rules emulator test, bat buoc chay truoc khi merge. Neu chua co test tu
dong, QA can ghi lai bang chung thao tac bi deny trong Emulator/console.

## 14. Test sandbox payOS that

Chi chay khi co credential sandbox hoac merchant test hop le.

1. Dat `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY` trong Firebase
   secrets/local secrets.
2. Dam bao webhook URL public tro ve:

```text
https://<function-host>/casTransactionsWebhook
```

3. Dang ky webhook theo huong dan payOS cho merchant.
4. Chay app, tao QR, thanh toan sandbox/test.
5. Xem Functions log va Firestore.

Ky vong giong local completed:

- Webhook verify pass.
- Payment completed dung mot lan.
- Subscription active.
- App foreground/resume/history deu dung.

Neu webhook that khong ve:

- Kiem tra URL function, region `asia-southeast1`, method `POST`.
- Kiem tra content type `application/json`.
- Kiem tra `PAYOS_CHECKSUM_KEY` co dung merchant/app dang gui webhook.
- Kiem tra log function `payOS webhook reconciliation failed` hoac response
  `401/415/500`.

## 15. Checklist truoc khi handoff

- [ ] `npm run lint` pass.
- [ ] `npm test` pass.
- [ ] `flutter analyze` pass.
- [ ] `flutter test test/features/payment` pass.
- [ ] Tao QR local/sandbox thanh cong.
- [ ] Pending payment co dung schema trong Firestore.
- [ ] Completed webhook activate Premium dung mot lan.
- [ ] Duplicate webhook khong gia han lan hai.
- [ ] Sai amount vao `requires_review`.
- [ ] Late payment vao `requires_review`.
- [ ] Cancel pending payment khong activate Premium.
- [ ] Expired pending payment khong activate Premium.
- [ ] Payment history hien dung pending/completed/failed/expired/cancelled/
  requires_review.
- [ ] UI khong bi overflow, countdown khong am, QR render duoc.
- [ ] Text tieng Viet tren payment screens khong bi mojibake.
- [ ] Client khong ghi duoc payment/subscription/reference protected docs.
- [ ] Khong co secret/token/provider raw payload trong Git, log, hoac Firestore
  client-readable.

## 16. File lien quan

- Backend callable tao order:
  `functions/src/payment/callables/create_cas_payment_order.ts`
- Backend callable huy order:
  `functions/src/payment/callables/cancel_cas_payment_order.ts`
- Backend reconcile va subscription:
  `functions/src/payment/services/payment_service.ts`
- payOS client:
  `functions/src/payment/services/payos_client.ts`
- payOS webhook verifier:
  `functions/src/payment/services/payos_webhook.ts`
- Webhook HTTP:
  `functions/src/payment/webhooks/cas_transactions_webhook.ts`
- Scheduler expiry:
  `functions/src/payment/schedules/expire_pending_payments.ts`
- Flutter datasource:
  `lib/features/payment/data/datasources/payment_remote_datasource.dart`
- Flutter controller:
  `lib/features/payment/presentation/providers/payment_provider.dart`
- Flutter screens:
  `lib/features/payment/presentation/pages/payment_page.dart`
  `lib/features/payment/presentation/pages/payment_qr_page.dart`
  `lib/features/payment/presentation/pages/payment_result_page.dart`
  `lib/features/payment/presentation/pages/payment_history_page.dart`
- Webhook replay local:
  `scripts/replay_cas_webhook.ps1`

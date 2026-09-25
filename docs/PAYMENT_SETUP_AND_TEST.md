# FOORA Payment - Cau hinh va kiem thu

Tai lieu nay dung cho local development va Cas sandbox. Production deployment
van do Tech Lead/DevOps thuc hien theo DEVELOPMENT_WORKFLOW.md.

## 1. Trang thai va dieu kien bat buoc

Co the chay ngay:

- Functions build, lint va unit tests.
- Flutter analyze va payment unit/widget tests.
- Firebase Emulator, seed user/membership, UI payment.
- Replay webhook TRANSACTIONS local de test completed, requires_review va
  idempotency.

Can dau vao ben ngoai de pass sandbox E2E that:

- Cas sandbox client ID va secret key.
- Merchant grant co scope qrpay va accessToken tu Cas Link.
- QR Pay duoc enable cho sandbox application.
- Webhook public URL, hoac staging function URL do Tech Lead cung cap.
- Xac nhan co che webhook production voi Cas. Tai lieu public hien chi cong bo
  source IP sandbox, khong cong bo chu ky webhook.

## 2. Cac file local da chuan bi

- functions/.env.local: Cas sandbox base URL va payment expiry.
- functions/.secret.local: ba placeholder Cas va mot webhook secret ngau nhien.
- .env.local.json: Flutter config voi USE_FIREBASE_EMULATOR=true.
- functions/.env.local.example va functions/.secret.local.example: template cho
  team.
- scripts/replay_cas_webhook.ps1: replay fixture webhook local.

Ba file local co du lieu moi truong da duoc git-ignore. Khong commit secret,
accessToken, URL webhook co token, hoac payload chua thong tin tai khoan that.

Sua ba gia tri REPLACE_WITH trong functions/.secret.local:

~~~dotenv
CAS_CLIENT_ID=<sandbox-client-id>
CAS_SECRET_KEY=<sandbox-secret-key>
CAS_ACCESS_TOKEN=<qrpay-access-token>
CAS_WEBHOOK_SECRET=<giu-nguyen-gia-tri-da-sinh>
~~~

CAS_ACCESS_TOKEN duoc gui nguyen gia tri trong header Authorization, khong them
tien to Bearer.

## 3. Tao merchant grant QR Pay tren Cas sandbox

### 3.1 Lay API key

Trong Cas Console, tao/chon sandbox application va lay x-client-id,
x-secret-key. Enable QR Pay va khai bao redirect URI duoc phep.

Trong PowerShell, dat bien tam cho phien hien tai:

~~~powershell
$env:CAS_CLIENT_ID = "<sandbox-client-id>"
$env:CAS_SECRET_KEY = "<sandbox-secret-key>"
$redirectUri = "https://<callback-domain>/cas-link/callback"

$headers = @{
  "X-BankHub-Api-Version" = "2023-01-01"
  "x-client-id" = $env:CAS_CLIENT_ID
  "x-secret-key" = $env:CAS_SECRET_KEY
}
~~~

### 3.2 Tao grantToken

~~~powershell
$grantBody = @{
  scopes = "qrpay"
  language = "vi"
  redirectUri = $redirectUri
} | ConvertTo-Json

$grantParams = @{
  Method = "Post"
  Uri = "https://sandbox.bankhub.dev/grant/token"
  Headers = $headers
  ContentType = "application/json"
  Body = $grantBody
}
$grant = Invoke-RestMethod @grantParams
$grant | ConvertTo-Json -Depth 8
~~~

grantToken co han 30 phut va chi dung mot lan.

### 3.3 Mo Cas Link va lay publicToken

~~~powershell
$state = [guid]::NewGuid().ToString("N")
$casLink = "https://dev.link.bankhub.dev?grantToken=$($grant.grantToken)&redirectUri=$([Uri]::EscapeDataString($redirectUri))&iframe=false&state=$state"
$casLink
~~~

Mo URL vua in ra, hoan thanh lien ket tai khoan sandbox. Callback phai tra ve
publicToken va dung state da gui. Neu callback cua du an chua co, dung mot
callback/tunnel da duoc team phe duyet; khong dua publicToken vao log chung.

### 3.4 Doi publicToken lay accessToken

~~~powershell
$publicToken = "<public-token-tu-callback>"
$exchangeBody = @{
  publicToken = $publicToken
} | ConvertTo-Json

$exchangeParams = @{
  Method = "Post"
  Uri = "https://sandbox.bankhub.dev/grant/exchange"
  Headers = $headers
  ContentType = "application/json"
  Body = $exchangeBody
}
$exchange = Invoke-RestMethod @exchangeParams
$exchange | ConvertTo-Json -Depth 8
~~~

Ghi accessToken tra ve vao CAS_ACCESS_TOKEN trong functions/.secret.local.

### 3.5 Xac minh tai khoan QR Pay

~~~powershell
$identityHeaders = $headers.Clone()
$identityHeaders["Authorization"] = "<access-token>"

$identityParams = @{
  Method = "Get"
  Uri = "https://sandbox.bankhub.dev/qr-pay/identity"
  Headers = $identityHeaders
}
Invoke-RestMethod @identityParams
~~~

Chi tiep tuc neu identity dung tai khoan merchant FOORA mong doi.

## 4. Quality gate tu dong

Chay tu root:

~~~powershell
flutter pub get

Push-Location functions
npm install
npm run lint
npm test
Pop-Location

flutter analyze
flutter test test/features/payment
~~~

Ky vong:

- Functions lint khong co error.
- Functions tests pass ca Cas request/response contract va webhook parser.
- Flutter analyze khong co issue.
- Payment tests pass.

Full Flutter suite hien co the bi anh huong boi fixture ngay het han cua feature
khac; neu co fail, tach ro payment regression va test ngoai pham vi.

## 5. Chay Firebase Emulator va app

### Terminal 1 - build watch

~~~powershell
Set-Location functions
npm run build:watch
~~~

### Terminal 2 - emulator suite

Tu root:

~~~powershell
firebase emulators:start --project foora-app
~~~

Port hien tai:

- Emulator UI: http://localhost:4000
- Auth: 9099
- Functions: 5001
- Firestore: 8080
- Storage: 9199

### Terminal 3 - seed du lieu

Sau khi emulator ready:

~~~powershell
Set-Location functions
npm run seed:emulator
~~~

Tai khoan test luong mua moi:

- Email: user.free@gmail.com
- Password: Password@123

Seed Premium dung subscription cas_premium, provider cas va autoRenew=false.

### Terminal 4 - Flutter

Liet ke device:

~~~powershell
flutter devices
~~~

Android emulator:

~~~powershell
flutter run -d <android-device-id> --dart-define-from-file=.env.local.json
~~~

Web:

~~~powershell
flutter run -d chrome --dart-define-from-file=.env.local.json
~~~

Android emulator tu dong dung host 10.0.2.2; web/iOS/desktop dung localhost.

## 6. Test local end-to-end bang webhook replay

1. Dang nhap user.free@gmail.com.
2. Mo Profile > Goi thanh vien > nang cap Premium.
3. Xac nhan tao QR.
4. Trong Emulator UI, mo users/{uid}/payments/{paymentId}.
5. Lay referenceNumber, vi du FOORAABC123.
6. Replay webhook truoc expiresAt:

~~~powershell
.\scripts\replay_cas_webhook.ps1 -ReferenceNumber "FOORAABC123" -TransactionId "local-e2e-001"
~~~

Response ky vong:

~~~json
{
  "success": true,
  "status": "completed"
}
~~~

Kiem tra Firestore va app:

- Payment status = completed.
- providerTransactionId = local-e2e-001.
- users/{uid}/subscriptions/cas_premium ton tai va active.
- Subscription autoRenew = false, lastPaymentId dung payment vua tao.
- users/{uid}.membershipId = premium.
- App dang mo tu chuyen sang success; app resume van doc dung status.
- Payment History hien giao dich.

### Idempotency

Chay lai dung TransactionId local-e2e-001. Ky vong response van 200/completed,
khong co provider transaction thu hai va endDate subscription khong tang them.

### Sai amount

Tao payment moi, sau do:

~~~powershell
.\scripts\replay_cas_webhook.ps1 -ReferenceNumber "<reference-moi>" -Amount 48000 -TransactionId "local-wrong-amount-001"
~~~

Ky vong payment = requires_review va subscription khong duoc gia han.

### Late payment

Tao payment moi, lay expiresAt, sau do replay voi thoi diem muon hon expiresAt:

~~~powershell
.\scripts\replay_cas_webhook.ps1 -ReferenceNumber "<reference-moi>" -TransactionId "local-late-001" -TransactionDateTime "2026-09-26T10:00:00+07:00"
~~~

Ky vong payment = requires_review, reviewReason = late_payment.

## 7. Test webhook Cas sandbox that

Localhost khong nhan duoc webhook tu Cas. Chon mot trong hai cach da duoc team
phe duyet:

1. Tech Lead deploy payment function len staging.
2. Dung HTTPS tunnel tam thoi, co access control va khong de lo URL token.

Webhook URL cau hinh trong Cas Console phai la URL function public kem token:

~~~text
https://<function-host>/casTransactionsWebhook?token=<CAS_WEBHOOK_SECRET>
~~~

Dang ky event TRANSACTIONS. Cas sandbox public docs hien cong bo source IP
20.2.69.168 va retry 17 lan trong 24 gio khi endpoint tra 4xx/5xx hoac timeout.

Khi Cas cung cap signature/header rieng trong merchant contract, cap nhat
handler theo contract do va thay URL secret. Khong tu suy doan X-Casso-Signature:
day la contract cua san pham khac, khong nam trong QR Pay docs hien hanh.

## 8. Handoff production cho Tech Lead/DevOps

Tech Lead dat bon secret trong Firebase Secret Manager:

~~~powershell
firebase functions:secrets:set CAS_CLIENT_ID --project foora-app
firebase functions:secrets:set CAS_SECRET_KEY --project foora-app
firebase functions:secrets:set CAS_ACCESS_TOKEN --project foora-app
firebase functions:secrets:set CAS_WEBHOOK_SECRET --project foora-app
~~~

Non-secret production config:

~~~dotenv
CAS_BASE_URL=https://production.bankhub.dev
CAS_QR_PAY_PATH=/qr-pay
PAYMENT_EXPIRY_MINUTES=15
~~~

Khong deploy neu CAS_BASE_URL van la sandbox. Sau deploy, lay URL thuc tu output
Firebase, dang ky webhook TRANSACTIONS trong Cas Console, deploy Rules/Indexes,
va smoke test voi gia tri nho da duoc phe duyet.

## 9. Definition of Done checklist

- [ ] Cas sandbox identity dung merchant FOORA.
- [ ] Tao QR sandbox thanh cong va qrCode render duoc.
- [ ] Webhook TRANSACTIONS that map paymentMeta.referenceNumber dung.
- [ ] completed activate Premium dung mot lan.
- [ ] Duplicate webhook khong gia han lan hai.
- [ ] Sai amount va late payment vao requires_review.
- [ ] Cancel va expiry khong tu activate Premium.
- [ ] App foreground/resume/history deu dung.
- [ ] Firestore Rules integration test pass.
- [ ] Flutter analyze va payment tests pass.
- [ ] Functions lint/build/tests pass.
- [ ] Stitch screenshot/golden duoc sign-off.
- [ ] Production webhook authentication/source duoc Cas va Tech Lead xac nhan.

## Tai lieu chinh thuc

- Cas QR Pay: https://cas.so/product/qr-pay/
- Cas Link: https://cas.so/general/link/
- Cas Webhook: https://cas.so/general/api/webhook/
- Firebase local Functions config:
  https://firebase.google.com/docs/emulator-suite/connect_functions

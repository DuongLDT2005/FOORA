# FOORA – AI CODE RULES

## 1. SOURCE OF TRUTH

Before coding, read:

```bash
docs/PROJECT_OVERVIEW.md
docs/PROJECT_STRUCTURE.md
docs/DATABASE.md
docs/FUNCTIONS_GUIDE.md
docs/SETUP.md
```

Rules:

```bash
- Follow the existing project structure.
- Follow the database schema exactly.
- Do not invent new business requirements.
- Do not change architecture without a reason.
- If requirements are ambiguous, stop and ask or mark TODO.
- All code comments (inline comments, docstrings, class/function annotations) MUST be written in English. Do not write Vietnamese comments in code.
```

---

## 2. ARCHITECTURE

Use:

```bash
Feature-Based Clean Architecture
```

Each feature:

```text
feature/
├── data/
├── domain/
└── presentation/
```

Dependency direction:

```text
Presentation
    ↓
Domain
    ↑
Data
```

More specifically:

```text
Page / Widget
    ↓
Provider
    ↓
UseCase
    ↓
Repository Interface
    ↑
Repository Implementation
    ↓
DataSource
    ↓
Firebase / External Service
```

Rules:

```bash
- Domain must not depend on Flutter.
- Domain must not depend on Firebase SDK.
- Domain must not depend on Firestore.
- Domain must not depend on Gemini.
- Domain must not depend on ML Kit.
- Domain must not depend on Cloud Functions.
- Data implements domain repository interfaces.
- Presentation communicates with domain through use cases.
```

---

## 3. UI RULES

```bash
- Widgets are responsible for UI only.
- Pages must not contain business logic.
- Widgets must not contain business logic.
- Pages must not access Firestore directly.
- Widgets must not access Firestore directly.
- Pages must not call Firebase services directly.
- Reusable widgets go to shared/.
- Feature-specific widgets stay inside the feature.
- Never hardcode raw Color(0x...) in UI/Widgets. Always use AppColors constants.
- When converting React/Tailwind code (e.g. text-slate-400, bg-slate-100, border-slate-200, bg-emerald-100, bg-amber-50, text-amber-800), ALWAYS map directly to AppColors constants (AppColors.slate400, AppColors.slate100, AppColors.emerald100, AppColors.amber50, AppColors.amber800,...). Do not use default Tailwind colors.
- Follow the Tailwind to Flutter Mobile Size Mapping Table below when converting web/React designs to ensure optimal mobile ergonomics and touch targets.
- Mobile Form UX: Always wrap scrollable form bodies with a GestureDetector(behavior: HitTestBehavior.opaque) calling FocusScope.of(context).unfocus() and keyboardDismissBehavior: onDrag to ensure virtual keyboards and blinking cursors properly dismiss when tapping outside or scrolling.
- Responsive UI Architecture: All UI components must adapt responsively across diverse phone screen densities, tablets, and web wrapper viewports using `flutter_screenutil` and `ContextExtensions`.
```

### Tailwind to Flutter Mobile Size Mapping

| Tailwind Class | Original Web Size | Mobile Fixed Size |
| :--- | :--- | :--- |
| `text-[9px]` | 9px | `12px` |
| `text-[10px]` | 10px | `13px` |
| `text-xs` (`text-[12px]`) | 12px | `15px` |
| `text-sm` (`text-[14px]`) | 14px | `16px` |
| `text-base` (`text-[16px]`) | 16px | `17px` |
| `text-lg` (`text-[18px]`) | 18px | `20px` |
| `text-xl` (`text-[20px]`) | 20px | `24px` |
| `text-2xl` (`text-[24px]`) | 24px | `28px` |
| `text-3xl` (`text-[30px]`) | 30px | `34px` |
| `py-2` / `py-2.5` | 8px / 10px | `vertical: 12` |
| `py-3` / `py-3.5` | 12px / 14px | `vertical: 16` |
| `h-10` / `h-11` / `h-12` | 40px / 44px / 48px | `height: 52` |

### Responsive UI Standards & Guidelines

```bash
1. Base Design Frame:
   - Initialized in main.dart: ScreenUtilInit(designSize: const Size(390, 844), minTextAdapt: true, splitScreenMode: true).
   - Standard reference device: iPhone 13/14/15 viewport (390 x 844 pt).

2. ScreenUtil Units Usage Rules:
   - Widths, horizontal margins/paddings: Use `.w` (e.g., `16.w`, `SizedBox(width: 12.w)`).
   - Heights, vertical margins/paddings: Use `.h` (e.g., `50.h`, `SizedBox(height: 16.h)`).
   - Radius, avatars, square buttons, circular containers, icons: Use `.r` (e.g., `BorderRadius.circular(16.r)`, `width: 40.r, height: 40.r`, `Icon(..., size: 20.r)`).
   - Font sizes: Use `.sp` (e.g., `fontSize: 14.sp`, `fontSize: 18.sp`).

3. Responsive Breakpoints (from ContextExtensions):
   - isMobile: screenWidth < 600 px.
   - isTablet: screenWidth >= 600 px && screenWidth < 1024 px.
   - isDesktop: screenWidth >= 1024 px.

4. Tablet / Web Constrained Layout Pattern:
   - Wide screens must NOT stretch phone forms or bottom sheets edge-to-edge.
   - Subpages (SubpageLayout): Enclosed in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 600.w)))`.
   - Bottom Action Bars (AppBottomBar): Enclosed in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 600.w)))`.
   - Modal Bottom Sheets (AppBottomSheet, ScannedItemsBottomSheet): Constrained to `maxWidth: 520.w` and centered.
   - Pop-up Dialogs (AppDialog): Constrained to `maxWidth: 420.w`.
   - Floating Card Overlays: Constrained to `maxWidth: 440.w`.
```

Bad:

```text
Widget
  ↓
Firestore
```

Good:

```text
Widget
  ↓
Provider
  ↓
UseCase
  ↓
Repository
  ↓
DataSource
  ↓
Firestore
```

---

## 4. DOMAIN RULES

Domain contains business rules.

```bash
- Entities represent business objects.
- UseCases represent business actions.
- Repository interfaces belong to domain.
- Domain code must be framework-independent.
- Do not put Firebase models inside domain entities.
- Do not put UI state inside domain entities.
```

Example:

```text
domain/
├── entities/
├── repositories/
└── usecases/
```

---

## 5. DATA RULES

Data layer handles external systems.

```bash
- Firebase access belongs in data/datasources/.
- External API access belongs in data/datasources/.
- Firebase models belong in data/models/.
- Repository implementations belong in data/repositories/.
- Convert Model ↔ Entity at the data/domain boundary.
- Do not expose Firebase SDK types to domain.
```

---

## 6. FIREBASE RULES

Firebase is the backend infrastructure.

Use:

```bash
Firebase Authentication
Cloud Firestore
Firebase Storage
Firebase Cloud Functions
Firebase Cloud Messaging
Firebase Emulator Suite
```

Rules:

```bash
- Do not create a separate Express/Node backend.
- Do not create MySQL/SQL Server.
- Do not access protected backend logic only from the client.
- Use Firebase Security Rules for access control.
- Use Cloud Functions for trusted server-side operations.
```

---

## 7. FIRESTORE RULES

Use the paths defined in:

```bash
docs/DATABASE.md
```

Rules:

```bash
- Do not change collection paths without updating the database specification.
- Do not duplicate master data unnecessarily.
- Do not store passwords in Firestore.
- Do not use allow read, write: if true;
- Validate authenticated user access.
- Validate household membership before accessing household data.
- Validate admin role for admin-only operations.
```

For user-owned data:

```text
users/{userId}/...
```

For household-owned inventory:

```text
households/{householdId}/inventory_items/{inventoryItemId}
```

---

## 8. FIREBASE AUTH RULES

Firebase Authentication is responsible for credentials.

Never store:

```bash
password
passwordHash
authenticationSecret
```

in Firestore.

Authenticated operations must verify:

```bash
request.auth != null
```

and ownership/access where required.

---

## 9. HOUSEHOLD RULES

Household is the owner of inventory.

```bash
- Verify the user belongs to the household.
- Verify activeHouseholdId when applicable.
- Never trust householdId supplied by the client without authorization.
- Do not allow users to access another household's inventory.
```

---

## 10. INVENTORY RULES

Inventory belongs to:

```text
households/{householdId}/inventory_items
```

Rules:

```bash
- Keep batches separate when expiration dates differ.
- Do not merge batches with different expiration dates.
- Use FEFO when consuming food.
- Validate quantity before updating.
- Validate household access before mutation.
- Apply membership limits server-side where required.
```

FEFO:

```text
earliest expirationDate
        ↓
consume first
```

---

## 11. MEMBERSHIP RULES

Membership configuration comes from Firestore.

Do not hard-code:

```bash
price
foodLimit
receiptScanQuota
durationDays
```

throughout the application.

Rules:

```bash
- Client may display membership configuration.
- Backend must enforce limits.
- Never trust client-provided membership status.
- Never trust client-provided quota values.
- Premium access must be validated server-side.
```

---

## 12. AI RULES

The Flutter client must never call Gemini directly.

Bad:

```text
Flutter → Gemini
```

Good:

```text
Flutter
   ↓
Cloud Function
   ↓
Authentication
   ↓
Authorization
   ↓
Quota
   ↓
Gemini
   ↓
Validated result
   ↓
Flutter
```

Rules:

```bash
- Gemini API credentials stay on the backend.
- Validate Firebase Authentication.
- Validate membership/permissions.
- Validate AI quota.
- Validate AI output.
- Do not allow AI to execute arbitrary Firestore operations.
- AI must operate only through explicitly supported intents/actions.
```

---

## 13. AI OUTPUT RULE

Never blindly trust model output.

Flow:

```text
Gemini output
    ↓
Validate structure
    ↓
Validate intent
    ↓
Validate parameters
    ↓
Validate authorization
    ↓
Execute allowed operation
```

The AI may suggest an operation, but:

```bash
Backend decides whether the operation is allowed.
```

---

## 14. QUOTA RULES

Quota must be enforced by the backend.

```bash
- Do not trust client-side usage counters.
- Prevent quota bypass.
- Handle concurrent requests safely.
- Reset usage according to the configured period.
- Read quota configuration from membership data.
```

---

## 15. RECEIPT / OCR RULES

OCR and AI processing must be separated from UI.

```text
Image
  ↓
Storage
  ↓
OCR
  ↓
Raw text
  ↓
Normalization
  ↓
Food matching
  ↓
Confirmation
  ↓
Inventory
```

Rules:

```bash
- Preserve raw OCR result.
- Keep normalized food name separate from raw OCR name.
- Do not automatically trust uncertain recognition.
- User confirmation is required before uncertain receipt data creates inventory.
```

---

## 16. STORAGE RULES

Storage structure:

```text
foods/{foodId}/*
users/{userId}/receipts/{receiptId}/*
```

Rules:

```bash
- Validate authenticated user.
- Validate userId against authenticated user.
- Do not allow arbitrary user file access.
- Do not expose unrestricted storage paths.
```

---

## 17. CLOUD FUNCTIONS RULES

Organize Functions by business responsibility:

```text
functions/src/
├── auth/
├── inventory/
├── receipt/
├── ai/
├── notification/
├── membership/
├── payment/
├── household/
└── index.ts
```

Rules:

```bash
- Keep functions small and focused.
- Do not put all backend logic in index.ts.
- Validate authentication inside protected functions.
- Validate authorization inside protected functions.
- Validate input.
- Handle errors explicitly.
- Never trust client-provided protected state.
```

---

## 18. SECURITY RULES

Every protected operation must answer:

```bash
Who is the user?
Does the user have access?
Is the user allowed to perform this action?
Is the data valid?
```

Never rely only on:

```bash
- Hidden UI buttons
- Client-side validation
- Client-side membership state
- Client-side quota
```

Security must exist at backend/rules level.

---

## 19. ERROR HANDLING

Do not expose raw Firebase/Gemini exceptions directly to UI.

Use:

```text
Datasource
    ↓
Exception
    ↓
Repository
    ↓
Failure
    ↓
Provider
    ↓
UI
```

UI should support:

```bash
loading
success
empty
error
retry
```

where appropriate.

---

## 20. STATE MANAGEMENT

Use the project's existing provider/state-management approach consistently.

Rules:

```bash
- UI state belongs in presentation.
- Business state should not be duplicated across widgets.
- Avoid unnecessary global state.
- Providers should coordinate UI state with use cases.
- Do not put Firestore queries directly inside widgets.
```

---

## 21. MODELS VS ENTITIES

Keep persistence models and domain entities separate.

```text
Firestore
    ↓
Model
    ↓
Entity
    ↓
UseCase
```

and:

```text
Entity
    ↓
Model
    ↓
Firestore
```

Do not make domain entities depend on Firestore `DocumentSnapshot`.

---

## 22. NAMING RULES

Use clear names based on business meaning.

Examples:

```text
InventoryItem
InventoryRepository
InventoryRepositoryImpl
InventoryRemoteDataSource
AddInventoryItem
GetInventory
UpdateInventoryItem
```

Avoid:

```text
DataManager
Helper2
ServiceNew
TempClass
CommonThing
```

unless the responsibility is genuinely generic.

---

## 23. FILE RESPONSIBILITY

One file should have one clear responsibility.

Avoid:

```bash
- Giant widgets
- Giant providers
- Giant repositories
- Giant Cloud Functions files
- Unrelated utility classes
```

Split code when responsibility becomes unclear.

---

## 24. SHARED CODE RULE

Put code in:

```text
shared/
```

only when it is genuinely reusable across multiple features.

Do not use:

```text
shared/
```

as a dumping ground.

Feature-specific code stays inside:

```text
features/{feature}/
```

---

## 25. DEPENDENCY RULE

Before adding a package:

```bash
1. Check whether Flutter/Firebase already provides the capability.
2. Check whether an existing project dependency provides it.
3. Add a package only when necessary.
4. Prefer maintained and focused packages.
```

Do not add dependencies just to avoid writing simple code.

---

## 26. ASYNC / FIREBASE RULES

```bash
- Handle loading states.
- Handle errors.
- Do not leave unhandled Futures.
- Do not perform expensive work inside build().
- Do not repeatedly create Firebase listeners during rebuilds.
- Dispose/cancel listeners when appropriate.
```

---

## 27. TESTING RULES

Every business rule should be testable independently of Flutter UI.

Prioritize tests for:

```bash
- UseCases
- FEFO
- Expiration calculation
- Membership limits
- AI quota
- Authorization-sensitive logic
- Receipt normalization
```

Before completing a change:

```bash
flutter analyze
flutter test
dart format lib test
```

For Functions:

```bash
cd functions
npm run build
cd ..
```

---

## 28. EMULATOR RULE

Use Firebase Emulator Suite during local backend development.

```bash
firebase emulators:start
```

Do not use production data for normal local development/testing.

Test:

```bash
- Firestore
- Functions
- Authentication
- Storage
```

when applicable to the implemented feature.

---

## 29. CODE CHANGE RULE

When modifying existing code:

```bash
1. Inspect the existing implementation.
2. Understand dependencies.
3. Make the smallest correct change.
4. Preserve working behavior.
5. Do not rewrite unrelated files.
6. Run formatter.
7. Run analyzer.
8. Run tests.
```

Do not rewrite the project simply to match personal coding preferences.

---

## 30. FEATURE IMPLEMENTATION RULE

When implementing a feature:

```text
Requirement
    ↓
Domain
    ↓
Data
    ↓
Backend / Firebase
    ↓
Presentation
    ↓
Tests
```

Do not start by putting all logic inside the UI and refactor later.

---

## 31. BACKEND-FIRST SECURITY RULE

If an operation affects:

```bash
money
membership
subscription
quota
permissions
household access
protected data
AI usage
```

assume it requires backend/server-side validation.

Client validation is only for UX.

---

## 32. PAYMENT RULE

Payment/subscription state must not be trusted from Flutter alone.

```text
Store
  ↓
Backend validation
  ↓
Subscription state
  ↓
Firestore
  ↓
Flutter
```

Never let the client simply set:

```text
membership = premium
```

as proof of payment.

---

## 33. NOTIFICATION RULE

Expiration notifications should be generated by trusted backend/scheduled processing.

```text
Scheduled Function
    ↓
Inventory
    ↓
Expiration check
    ↓
Notification document
    ↓
FCM
```

Avoid relying on the mobile application being open to perform critical reminder processing.

---

## 34. ADMIN RULE

Admin authorization must be enforced by backend/security rules.

Do not rely only on:

```bash
if (user.role == admin) showAdminButton();
```

UI visibility is not authorization.

---

## 35. NO FEATURE CREEP

Do not implement unrequested features.

For MVP, do not add speculative systems such as:

```bash
- Separate Express backend
- SQL database
- Microservices
- GraphQL
- Image-based food recognition
- Complex recommendation engine
- Unrequested analytics
- Unrequested social features
```

---

## 36. BEFORE CODING

Run:

```bash
flutter doctor -v
flutter pub get
flutter analyze
```

Check:

```bash
- Firebase configuration
- Current project structure
- Existing dependencies
- Existing routes
- Existing providers
- Existing Firebase initialization
```

Do not recreate existing configuration.

---

## 37. AFTER CODING

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

If Functions were changed:

```bash
cd functions
npm run build
cd ..
```

If Firebase behavior was changed:

```bash
firebase emulators:start
```

Fix errors before moving to the next task.

---

## 38. CORE & SHARED REUSE RULES

Always reuse the established shared infrastructure and components. Do not write duplicate helper functions or create ad-hoc styled widgets.

### A. Core Constants, Enums & Keys
- Use `AppEnums` (`UserRole`, `MembershipTier`, `StorageLocationCode`, `InventoryItemSource`, `ReceiptStatus`, `NotificationType`, `AppPlatform`, `SubscriptionStatus`, `PaymentStatus`) for all fixed domain field types instead of raw strings.
- Use `FirestoreConstants` for all Firestore collection names and document IDs (e.g. `FirestoreConstants.users`, `FirestoreConstants.households`, `FirestoreConstants.aiUsageCurrentDoc`).
- Use `StorageConstants` for Cloud Storage paths (`StorageConstants.receipts`, `StorageConstants.foods`).
- Use `StorageKeys` for all local `SharedPreferences` keys (`StorageKeys.activeHouseholdId`, `StorageKeys.themeMode`, etc.).
- Use `AppConstants` for global timeouts, page sizes, and default date patterns.

### B. Core Utilities
- Use `DateFormatter` for date formatting (`formatDate`, `formatDateTime`), FEFO expiration calculation (`getDaysUntilExpiry`, `getExpiryStatus`), and Vietnamese relative labels (`formatExpiryRelative`).
- Use `CurrencyFormatter` for formatting VND amounts (`CurrencyFormatter.formatVND`).
- Use `InputValidators` for all form input validation (`validateEmail`, `validatePassword`, `validateRequired`, `validatePositiveNumber`).
- Use `AppLogger` (`AppLogger.d`, `AppLogger.i`, `AppLogger.w`, `AppLogger.e`) instead of `print()` or `debugPrint()`.

### C. Shared UI Widgets
- **Icons**: Use `lucide_icons_flutter` (`LucideIcons`) for all modern vector icons.
- **Buttons**: Use `PrimaryButton`, `SecondaryButton`, `DangerButton`, and `AppFloatingActionButton` from `lib/shared/widgets/app_button.dart`.
- **Form Inputs**: Use `AppTextField`, `AppDropdown`, and `AppPercentageSlider` from `lib/shared/widgets/app_text_field.dart`.
- **Cards**: Use `FeatureCard` and `StatisticCard` from `lib/shared/widgets/app_card.dart` for generic banners/statistics. Food inventory item cards belong strictly to `lib/features/inventory/presentation/widgets/inventory_item_card.dart`.
- **Badges & Avatars**: Use `StatusBadge` and `CategoryAvatar` from `lib/shared/widgets/status_badge.dart`.
- **Headers**: Use `AppHeader` from `lib/shared/components/app_header.dart` (variants: `itemForm`, `notifications`, `profileDetail`, `membership`, `paymentHistory`).
- **Bottom Action Bars**: Use `AppBottomBar` from `lib/shared/components/app_bottom_bar.dart` (variants: `form`, `membership`).
- **Modals & Toasts**: Use `BottomSheetHelper.show` from `lib/shared/helpers/bottom_sheet_helper.dart` (wrapping `AppBottomSheet` from `lib/shared/components/app_bottom_sheet.dart`) and `ToastHelper.show` from `lib/shared/helpers/toast_helper.dart`.
- **Dialogs**: Use `DialogHelper` from `lib/shared/helpers/dialog_helper.dart` (wrapping `AppDialog` from `lib/shared/components/app_dialog.dart`).
- **State Views**: Use `LoadingWidget` / `AppLoadingSpinner` / `FullScreenLoader`, `EmptyStateWidget`, and `ErrorStateWidget`.

---

## 39. BACKEND CLOUD FUNCTIONS RULES (`functions/`)

Backend code in `functions/src/` must adhere strictly to the 3-Layer Architecture defined in `docs/FUNCTIONS_GUIDE.md`:

### A. Layer Coding Rules
1. **Entrypoint Layer (`index.ts` / Callable / Trigger / Scheduled)**:
   - Must be thin (< 30 lines).
   - Responsible only for: auth check (`getAuthenticatedUser` / `verifyAdmin`), input validation (`throwInvalidArgument`), delegating to Service, and returning `ApiResponse<T>`.
2. **Service Layer (`services/`)**:
   - Contains 100% of business logic, Gemini AI orchestration, IAP verification, and Firestore transactions.
   - Clean, testable, independent of Firebase Functions request wrappers.
3. **Infrastructure & Shared Layer (`config/`, `constants/`, `utils/`, `types/`)**:
   - Admin SDK singleton in `config/firebase.ts`.
   - Firestore collections constant mapped 1:1 with `DATABASE.md` in `constants/collections.ts`.
   - Error handlers (`throwUnauthenticated`, `throwPermissionDenied`, `throwNotFound`, `handleFunctionError`) must return `never`.

### B. TypeScript Quality & Verification
- Strict typing enabled (`noImplicitAny`, `strictNullChecks`). No `any` without justification.
- Before committing backend code, always run:
  ```bash
  cd functions
  npm run lint
  npm run build
  cd ..
  ```

---

## 40. FINAL PRINCIPLE

```bash
KEEP THE UI THIN.
KEEP THE DOMAIN CLEAN.
KEEP FIREBASE OUT OF THE DOMAIN.
KEEP BUSINESS RULES OUT OF WIDGETS.
KEEP TRUSTED OPERATIONS ON THE BACKEND.
KEEP BACKEND HANDLERS THIN, PUT BUSINESS IN SERVICES.
KEEP SECURITY ON THE SERVER.
KEEP THE DATABASE CONSISTENT.
KEEP CHANGES SMALL.
DO NOT INVENT REQUIREMENTS.
```

# END


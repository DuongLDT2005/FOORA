# FOORA – Smart Household Food Tracking & Expiration Management

<p align="center">
  <strong>FOORA</strong> is a modern mobile application designed to simplify household food inventory tracking and expiration management. By helping users track food quantities, monitor expiration dates, and prioritize consumption, FOORA aims to reduce duplicate purchases, minimize household food waste, and evolve into an AI-powered personal kitchen assistant.
</p>

---

## 🚀 Key Features

- **Smart Food Inventory**: Log and track food items with category, quantity, unit, storage location (e.g., Refrigerator, Freezer), and individual batches.
- **First Expired, First Out (FEFO)**: Intelligently prioritize food items that are closest to expiration to ensure they are consumed first.
- **Expiration Management & Smart Reminders**: Receive real-time alerts and upcoming expiration reminders powered by Firebase Cloud Messaging (FCM).
- **Receipt Scanning (OCR)**: Quickly import food items from supermarket receipts using Google ML Kit Text Recognition.
- **AI Normalization & Queries**: Process receipt text and perform natural-language queries about your inventory using the Gemini API.
- **Household Sharing**: Manage food inventory collectively with members of the same household.
- **Flexible Membership Plans**: Offers both Free and Premium tiers with configured AI usage limits.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Cloud Firestore, Firebase Authentication, Firebase Storage, Firebase Cloud Messaging (FCM)
- **Server-Side Logic**: Firebase Cloud Functions (TypeScript)
- **AI Integration**: Gemini API (via backend Cloud Functions for security)
- **Local Backend testing**: Firebase Emulator Suite
- **On-Device AI**: Google ML Kit OCR (Text Recognition)

---

## 📂 Project Documentation

Detailed project architecture, setup procedures, and database designs can be found in the `docs` folder:

- 📖 **[Project Overview](file:///d:/Yna/Study/TERM_8/EXE201/FOORA/docs/PROJECT_OVERVIEW.md)**: Deep dive into project goals, target users, user roles, and features.
- 🛠️ **[Development Setup Guide](file:///d:/Yna/Study/TERM_8/EXE201/FOORA/docs/SETUP.md)**: Requirements, dependencies, and steps to run the application and local Firebase emulators.
- 🔄 **[Development Workflow](file:///d:/Yna/Study/TERM_8/EXE201/FOORA/docs/DEVELOPMENT_WORKFLOW.md)**: Step-by-step developer guidelines from creating branches, local emulator testing, to pull requests.
- 🗃️ **[Database Design](file:///d:/Yna/Study/TERM_8/EXE201/FOORA/docs/DATABASE.md)**: Details of Firestore collections, subcollections, fields, and security rules.
- 🏢 **[Project Structure & Architecture](file:///d:/Yna/Study/TERM_8/EXE201/FOORA/docs/PROJECT_STRUCTURE.md)**: Explanation of Feature-Based Clean Architecture.

---

## ⚡ Quick Start

### 1. Prerequisites

Ensure you have the following installed:

- Flutter SDK & Dart SDK
- Node.js (for Firebase CLI and Cloud Functions dependencies)
- Android Studio & Emulator

### 2. Install Dependencies

Run the following commands to set up the Flutter app and backend Cloud Functions:

```bash
# Get Flutter dependencies
flutter pub get

# Get Cloud Functions dependencies
cd functions
npm install
cd ..
```

### 3. Setup Environment Variables & Firebase

1. Copy `.env.example.json` to `.env.json`:
   ```bash
   cp .env.example.json .env.json
   ```
2. Fill in your Firebase API keys into `.env.json` (or generate them via `flutterfire configure`).

### 4. Run Firebase Emulators (Optional)

For local development, start the Firebase Emulator Suite (Firestore, Auth, Functions, Storage):

```bash
firebase emulators:start
```

> 💡 _Emulator UI dashboard will be available at `http://localhost:4000`._

### 5. Run & Build the Application

Start your Android Emulator, connect a physical device, or run on Web:

```bash
# Run with Environment Variables (Default Dev with Emulators)
flutter run --dart-define-from-file=.env.json

# Run for Web (Admin)
flutter run -d chrome --dart-define-from-file=.env.json

# Run with Production Environment (Connect to live Firebase Cloud)
flutter run --dart-define-from-file=.env.json --dart-define=ENV=prod

# Run Dev Environment with live Firebase Cloud (Explicitly disable emulators)
flutter run --dart-define-from-file=.env.json --dart-define=USE_FIREBASE_EMULATOR=false

# Build APK (Release)
flutter build apk --release --dart-define-from-file=.env.json

# Build App Bundle (for Google Play)
flutter build appbundle --release --dart-define-from-file=.env.json
```

> 💡 **VS Code tip**: You can directly press **F5** or use the Run & Debug panel, as `.vscode/launch.json` is pre-configured with `--dart-define-from-file=.env.json`.


---

## ☁️ Cloud Functions Development

The backend logic and Gemini AI processing reside in the [`functions/`](file:///d:/Yna/Study/TERM_8/EXE201/FOORA/functions) directory (Node.js & TypeScript).

### Useful Scripts

| Command                               | Description                                       |
| :------------------------------------ | :------------------------------------------------ |
| `cd functions && npm install`         | Install backend dependencies                      |
| `cd functions && npm run build`       | Compile TypeScript to JavaScript (`lib/`)         |
| `cd functions && npm run build:watch` | Watch mode: auto-compile on TS file changes       |
| `cd functions && npm run lint`        | Run ESLint to verify code style & syntax          |
| `cd functions && npm run serve`       | Start local emulator for Functions only           |
| `firebase deploy --only functions`    | Deploy all Cloud Functions to Firebase production |
| `firebase functions:log`              | View live logs from deployed Cloud Functions      |

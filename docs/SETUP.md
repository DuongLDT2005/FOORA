# FOORA - Development Setup

## 1. Required Versions

```bash
Flutter
Dart
Android SDK: 36.0.0
Android Build Tools: 36.0.0
Android Emulator: 37.1.11.0
Android API: 37
JDK: OpenJDK 25.0.2
```

> Flutter and Dart extensions are required in VS Code.

---

## 2. Install Required Software

### Flutter SDK

Open VS Code and install these extensions:

```text
Flutter
Dart
```

The Flutter extension will automatically configure Dart support.

Add Flutter to PATH

```bash
Path_folder_install_flutter\bin
```

Check:

```bash
flutter --version
dart --version
```

---

### Android Studio

Download:

```bash
https://developer.android.com/studio
```

In Android Studio:

```bash
SDK Manager
```

Ensure Android SDK is installed. Then:

```bash
SDK Tools
Check "Show Package Details"
```

Required:

```bash
Android SDK Build-Tools: 36.0.0
Android SDK Command-line Tools: 20.0.0
Android Emulator: 37.1.11.0
Android SDK Platform-Tools: 37.0.1
```

---

### Android Emulator

In Android Studio:

```bash
Device Manager
   ↓
Create Device
```

Select:

```bash
Pixel 6a
```

Then, start the emulator.

Check:

```bash
flutter devices
```

Required:

```bash
sdk gphone...
```

---

### Accept Android Licenses

Run:

```bash
flutter doctor --android-licenses
```

Press "y" to accept all prompt questions:

```bash
y
```

Check:

```bash
flutter doctor
```

The Android toolchain section should display:

```bash
[✓] Android toolchain
```

---

## 3. Java / JDK

FOORA currently uses the JDK bundled with Android Studio.

Check:

```bash
flutter doctor -v
```

Current configuration:

```bash
JDK: OpenJDK 25.0.2
```

If Flutter cannot find the correct JDK:

```bash
flutter config --jdk-dir="PATH_TO_JDK"
```

Example:

```bash
flutter config --jdk-dir="E:\Android Studio\jbr"
```

Check again:

```bash
flutter doctor -v
```

---

## 4. Install Flutter Dependencies

Run:

```bash
flutter pub get
```

---

## 5. Firebase Cloud Functions & Emulator Setup

### Install Dependencies for Cloud Functions:

Navigate to the `functions/` directory and install the Node.js packages:

```bash
cd functions
npm install
cd ..
```

### Start Firebase Emulator Suite:

To develop offline and test Cloud Functions locally, start the emulators:

```bash
firebase emulators:start
```

---

## 6. Firebase CLI

Install Node.js first (if not):

```bash
https://nodejs.org/
```

Then install Firebase CLI:

```bash
npm install -g firebase-tools
```

Check:

```bash
firebase --version
```

Login:

```bash
firebase login
```

Check Firebase projects:

```bash
firebase projects:list
```

---

## 7. Firebase Configuration

The project already contains the required Firebase configuration.

After cloning, **do not run**:

```bash
flutterfire configure
```

---

## 8. Check Development Environment

Run:

```bash
flutter doctor -v
```

Make sure there are no issues:

```text
No issues found!
```

---

## 9. Check Available Devices

Run:

```bash
flutter devices
```

You should have an Android Emulator available.

Example:

```text
sdk gphone16k x86 64 • emulator-5554 • android-x64
```

---

## 10. Start Android Emulator

Open Android Studio:

```text
Android Studio
    ↓
Device Manager
    ↓
Start Emulator
```

Check:

```bash
flutter devices
```

---

## 11. Run FOORA

From the project root:

```bash
# Run with Local Firebase Emulators (Default Dev)
flutter run

# To run on a specific device with emulators
flutter run -d emulator-5554

# Run for Web (Admin with Local Emulators)
flutter run -d chrome

# Run with Production Environment (Connect to live Firebase Cloud by default)
flutter run --dart-define=ENV=prod

# Run Dev Environment with live Firebase Cloud (Explicitly disable emulators)
flutter run --dart-define=USE_FIREBASE_EMULATOR=false
```

---

## 12. Clean Project

If the project has build/dependency problems:

```bash
flutter clean
```

Then:

```bash
flutter pub get
```

Then:

```bash
flutter run
```

---

## 13. Common Setup Commands

Check Flutter:

```bash
flutter --version
```

Check environment:

```bash
flutter doctor -v
```

Check devices:

```bash
flutter devices
```

Install dependencies:

```bash
flutter pub get
```

Clean build:

```bash
flutter clean
```

Run application:

```bash
# Run with Environment Variables
flutter run --dart-define-from-file=.env.json
```

Build application:

```bash
# Build APK
flutter build apk --release --dart-define-from-file=.env.json

# Build App Bundle
flutter build appbundle --release --dart-define-from-file=.env.json
```

Firebase login:

```bash
firebase login
```

Check Firebase projects:

```bash
firebase projects:list
```

---

## 14. Quick Setup

After cloning the project:

```bash
flutter --version

flutter doctor -v

flutter pub get

# Setup Environment Variables
cp .env.example.json .env.json
# (Edit .env.json with appropriate Firebase API keys)

# Setup Cloud Functions dependencies
cd functions && npm install && cd ..

# Login Firebase
firebase login

# Run Firebase Emulators in background / separate terminal
firebase emulators:start

# Seed Master Data (Categories, Foods, Shelf-life rules, Memberships)
cd functions && npm run seed:emulator && cd ..

# Run app (connected to Local Emulators with environment variables)
flutter devices
flutter run --dart-define-from-file=.env.json --dart-define=USE_FIREBASE_EMULATOR=true
```

If everything is configured correctly, FOORA should start on the Android Emulator with local backend services running.


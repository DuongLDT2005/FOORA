import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';

class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (AppConfig.instance.useFirebaseEmulator) {
      final host = _resolveEmulatorHost();

      // Auth Emulator (Port 9099)
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);

      // Firestore Emulator (Port 8080)
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

      // Functions Emulator (Port 5001)
      FirebaseFunctions.instanceFor(region: AppConstants.firebaseRegion)
          .useFunctionsEmulator(host, 5001);

      // Storage Emulator (Port 9199)
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);

      if (kDebugMode) {
        print(
          '🔥 Connected to Firebase Emulators at $host (Auth: 9099, Firestore: 8080, Functions: 5001, Storage: 9199)',
        );
      }
    }
  }

  static String _resolveEmulatorHost() {
    if (kIsWeb) {
      return 'localhost';
    }
    if (Platform.isAndroid) {
      return AppConfig.instance.emulatorHost;
    }
    // iOS Simulator, macOS, Linux, Windows
    return 'localhost';
  }
}

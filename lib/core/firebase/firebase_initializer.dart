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
import '../utils/app_logger.dart';

class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (!kIsWeb && Platform.isAndroid && options.apiKey.isEmpty) {
          // APK built without --dart-define-from-file: fall back to the
          // native config from android/app/google-services.json.
          await Firebase.initializeApp();
        } else {
          await Firebase.initializeApp(options: options);
        }
      }
    } catch (e) {
      // Ignore duplicate-app error which can happen during Hot Restart
      // or if native Android auto-initialized it via google-services.json
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }

    if (AppConfig.instance.useFirebaseEmulator) {
      final host = _resolveEmulatorHost();

      await _configureEmulator(
        'Auth',
        () => FirebaseAuth.instance.useAuthEmulator(host, 9099),
      );
      await _configureEmulator('Firestore', () async {
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      });
      await _configureEmulator('Functions', () async {
        FirebaseFunctions.instanceFor(
          region: AppConstants.firebaseRegion,
        ).useFunctionsEmulator(host, 5001);
      });
      await _configureEmulator(
        'Storage',
        () => FirebaseStorage.instance.useStorageEmulator(host, 9199),
      );
      await _ensureUsableEmulatorAuthSession();

      AppLogger.i(
        'Connected to Firebase Emulators at $host '
        '(Auth: 9099, Firestore: 8080, Functions: 5001, Storage: 9199).',
      );
    }
  }

  static Future<void> _configureEmulator(
    String service,
    Future<void> Function() configure,
  ) async {
    try {
      await configure();
    } catch (error, stackTrace) {
      // A hot restart can configure an existing native Firebase instance twice.
      // Keep configuring the remaining services and make unexpected mismatches
      // visible instead of silently leaving only part of Firebase on emulators.
      AppLogger.e('Could not configure $service emulator.', error, stackTrace);
    }
  }

  /// Auth Emulator data is reset whenever its process restarts, while Android
  /// can retain the old refresh token. Sign that stale user out so the router
  /// shows the login screen instead of failing every authenticated call.
  static Future<void> _ensureUsableEmulatorAuthSession() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      const staleCodes = {
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
        'user-disabled',
      };
      // Network errors (Auth Emulator not started yet) keep the session.
      if (staleCodes.contains(error.code)) {
        await auth.signOut();
      } else {
        AppLogger.w('Could not verify the emulator session: ${error.code}');
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

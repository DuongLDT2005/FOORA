import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/app_logger.dart';

/// Wraps speech_to_text so features never touch the plugin directly.
class VoiceInputService {
  VoiceInputService(this._speech);

  final SpeechToText _speech;

  /// Returns false when the device has no recognizer or the mic permission
  /// is denied.
  Future<bool> initialize() async {
    try {
      return await _speech.initialize(
        onError: (e) => AppLogger.w('STT error: ${e.errorMsg}'),
        debugLogging: !kReleaseMode,
      );
    } catch (e, st) {
      AppLogger.e('Speech recognizer unavailable', e, st);
      return false;
    }
  }

  /// Vietnamese when installed, otherwise null (the device default).
  Future<String?> resolveVietnameseLocaleId() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('vi')) {
        return locale.localeId;
      }
    }
    return null;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
    required String? localeId,
  }) {
    return _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();

  bool get isListening => _speech.isListening;
}

final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  return VoiceInputService(SpeechToText());
});

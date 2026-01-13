import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class SpeechService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static Function(String)? _onError;
  static Function(String)? _onStatus;
  
  static Future<bool> init() async {
    if (_speech.isAvailable) return true;
    return await _speech.initialize(
      onStatus: (status) {
        debugPrint('STT Status: $status');
        _onStatus?.call(status);
      },
      onError: (error) {
        debugPrint('STT Error: $error');
        _onError?.call(error.errorMsg);
      },
    );
  }

  static Future<void> startListening({
    required Function(String) onResult,
    Function(double)? onSoundLevelChange,
    Function(String)? onError,
    Function(String)? onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;

    bool available = await init();
    if (available) {
      _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords.trim());
        },
        onSoundLevelChange: onSoundLevelChange,
        localeId: 'es_ES',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
    } else {
      if (onError != null) onError('Micrófono no disponible');
    }
  }

  static void stopListening() {
    _speech.stop();
  }

  static bool get isListening => _speech.isListening;
  static bool get isAvailable => _speech.isAvailable;
}

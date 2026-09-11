import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _isSoundOn = true;
  bool _isInitialized = false;

  TtsService._internal();

  /// Call this method before invoking speak()
  Future<void> initTts() async {
    if (_isInitialized) return;

    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
    await _tts.awaitSpeakCompletion(true);
    _isInitialized = true;
  }

  void setSoundState(bool enabled) {
    _isSoundOn = enabled;
    if (!enabled) stop();
  }

  Future<void> speak(String text, {String languageCode = 'en'}) async {
    if (!_isSoundOn || text.trim().isEmpty) return;
    if (!_isInitialized) await initTts();

    await stop();

    String locale = 'en-US';
    if (languageCode == 'as' || languageCode == 'bn') {
      locale = 'bn-IN';
    }

    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
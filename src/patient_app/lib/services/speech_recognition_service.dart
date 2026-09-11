import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'voice_navigation_service.dart';
import 'voice_navigation_coordinator.dart';
import 'locale_service.dart';

/// Current state of the speech recognition engine.
enum SpeechRecognitionState {
  idle,
  ready,
  listening,
  processing,
  error,
}

/// Service wrapping Android's built-in [SpeechRecognizer] engine
/// via platform method channel, supporting continuous "always-active" listening.
class SpeechRecognitionService extends ChangeNotifier {
  static final SpeechRecognitionService instance = SpeechRecognitionService._internal();
  SpeechRecognitionService._internal() {
    _initChannel();
  }
  factory SpeechRecognitionService() => instance;

  static const String channelName = 'com.smritikunj.patient_app/speech_recognition';
  MethodChannel _channel = const MethodChannel(channelName);

  SpeechRecognitionState _state = SpeechRecognitionState.idle;
  SpeechRecognitionState get state => _state;

  bool _isAlwaysActive = false;
  bool get isAlwaysActive => _isAlwaysActive;

  Timer? _restartTimer;
  Timer? _actionTimer;
  bool _isExecutingAction = false;

  String _currentLanguage = 'en-IN';
  String get currentLanguage => _currentLanguage;

  String _partialText = '';
  String get partialText => _partialText;

  List<String> _lastResults = <String>[];
  List<String> get lastResults => List.unmodifiable(_lastResults);

  double _rmsDb = 0.0;
  double get rmsDb => _rmsDb;

  String? _lastError;
  String? get lastError => _lastError;

  // Stream controllers for reactive subscribers
  final _stateController = StreamController<SpeechRecognitionState>.broadcast();
  final _rmsController = StreamController<double>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _resultController = StreamController<List<String>>.broadcast();

  Stream<SpeechRecognitionState> get onStateChanged => _stateController.stream;
  Stream<double> get onRmsChanged => _rmsController.stream;
  Stream<String> get onPartialResult => _partialController.stream;
  Stream<List<String>> get onResult => _resultController.stream;

  // Optional mock handler for tests
  Future<dynamic> Function(MethodCall call)? _mockMethodCallHandler;

  @visibleForTesting
  void setMockMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    _mockMethodCallHandler = handler;
  }

  @visibleForTesting
  void setMockChannel(MethodChannel channel) {
    _channel = channel;
    _initChannel();
  }

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSpeechStateChanged':
          final raw = call.arguments?['state'] as String? ?? 'idle';
          _updateState(_stateFromString(raw));
          break;

        case 'onRmsChanged':
          final rms = (call.arguments?['rms'] as num?)?.toDouble() ?? 0.0;
          _rmsDb = rms;
          _rmsController.add(rms);
          notifyListeners();
          break;

        case 'onPartialResult':
          final list = (call.arguments?['results'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];
          _partialText = list.isNotEmpty ? list.first : '';
          _partialController.add(_partialText);
          notifyListeners();

          // Check partial result for instant keyword match in always-active mode
          if (_isAlwaysActive && !_isExecutingAction && _partialText.isNotEmpty) {
            final match = VoiceNavigationService.instance.parseSingle(_partialText);
            if (match != null && match.confidence >= 0.88) {
              _triggerCommand(match.command);
            }
          }
          break;

        case 'onSpeechResult':
          final list = (call.arguments?['results'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];
          _lastResults = list;
          _partialText = list.isNotEmpty ? list.first : '';
          _updateState(SpeechRecognitionState.idle);
          _resultController.add(list);
          notifyListeners();

          if (_isAlwaysActive && !_isExecutingAction) {
            final match = VoiceNavigationService.instance.parseCandidates(list);
            if (match != null) {
              _triggerCommand(match.command);
            } else {
              // No command recognized, restart listening seamlessly
              _scheduleContinuousRestart(const Duration(milliseconds: 350));
            }
          }
          break;

        case 'onSpeechError':
          final code = call.arguments?['code'] as int? ?? -1;
          final msg = call.arguments?['message'] as String? ?? 'Recognition error';
          _lastError = '$msg ($code)';
          _updateState(SpeechRecognitionState.error);

          // If always active, seamlessly restart on timeout / no match error
          if (_isAlwaysActive && !_isExecutingAction) {
            _scheduleContinuousRestart(const Duration(milliseconds: 500));
          }
          break;
      }
    });
  }

  void _triggerCommand(VoiceCommand command) {
    if (_isExecutingAction) return;
    _isExecutingAction = true;
    _restartTimer?.cancel();

    // Execute through global coordinator
    VoiceNavigationCoordinator.instance.execute(command);

    // After action triggers and screen transitions, resume listening if still active
    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(milliseconds: 1400), () {
      _isExecutingAction = false;
      if (_isAlwaysActive) {
        _scheduleContinuousRestart(const Duration(milliseconds: 200));
      }
    });
  }

  void _scheduleContinuousRestart(Duration delay) {
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () async {
      if (_isAlwaysActive && !_isExecutingAction) {
        final lang = _determineLanguage();
        await startListening(language: lang);
      }
    });
  }

  String _determineLanguage() {
    final lang = LocaleService.instance.lang;
    return lang == AppLang.assamese ? 'bn-IN' : 'en-IN';
  }

  /// Toggles continuous listening ON / OFF.
  Future<void> toggleAlwaysActive({BuildContext? context}) async {
    if (_isAlwaysActive) {
      await stopAlwaysActive(context: context);
    } else {
      await startAlwaysActive(context: context);
    }
  }

  /// Activates continuous listening mode.
  Future<bool> startAlwaysActive({BuildContext? context}) async {
    final hasPerm = await hasPermission();
    if (!hasPerm) {
      final granted = await requestPermission();
      if (!granted) {
        _showToast(context, 'Microphone permission required for Voice Navigation');
        return false;
      }
    }

    _isAlwaysActive = true;
    _isExecutingAction = false;
    final lang = _determineLanguage();
    final success = await startListening(language: lang);

    notifyListeners();

    final isBengali = lang.startsWith('bn');
    _showToast(
      context,
      isBengali
          ? '🎙️ ভয়েস নির্দেশিকা চালু: বলুন খেলা, বাজারের যাত্রা, ট্যাপ, প্যাটার্ন বা লগআউট'
          : '🎙️ Voice active: Say Game, Market Trip, Tap target, Pattern match, or Logout',
      isActive: true,
    );

    return success;
  }

  /// Deactivates continuous listening mode.
  Future<void> stopAlwaysActive({BuildContext? context}) async {
    _isAlwaysActive = false;
    _restartTimer?.cancel();
    _actionTimer?.cancel();
    await cancel();
    notifyListeners();

    final isBengali = _currentLanguage.startsWith('bn');
    _showToast(
      context,
      isBengali ? '🎙️ ভয়েস নির্দেশিকা বন্ধ করা হয়েছে' : '🎙️ Voice listening paused',
      isActive: false,
    );
  }

  void _showToast(BuildContext? context, String message, {bool isActive = false}) {
    final ctx = context ?? VoiceNavigationCoordinator.navigatorKey.currentContext;
    if (ctx == null) return;

    try {
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: isActive ? const Color(0xFF2E6F40) : const Color(0xFF2C2523),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      );
    } catch (_) {}
  }

  void _updateState(SpeechRecognitionState newState) {
    _state = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  SpeechRecognitionState _stateFromString(String s) {
    switch (s) {
      case 'ready':
        return SpeechRecognitionState.ready;
      case 'listening':
        return SpeechRecognitionState.listening;
      case 'processing':
        return SpeechRecognitionState.processing;
      case 'error':
        return SpeechRecognitionState.error;
      case 'idle':
      default:
        return SpeechRecognitionState.idle;
    }
  }

  /// Checks if speech recognition service is available on Android.
  Future<bool> isAvailable() async {
    if (_mockMethodCallHandler != null) {
      final res = await _mockMethodCallHandler!(const MethodCall('isAvailable'));
      return res as bool? ?? false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if RECORD_AUDIO permission is granted.
  Future<bool> hasPermission() async {
    if (_mockMethodCallHandler != null) {
      final res = await _mockMethodCallHandler!(const MethodCall('hasPermission'));
      return res as bool? ?? false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('hasPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests microphone permission if not yet granted.
  Future<bool> requestPermission() async {
    if (_mockMethodCallHandler != null) {
      final res = await _mockMethodCallHandler!(const MethodCall('requestPermission'));
      return res as bool? ?? false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts listening using Android's built-in SpeechRecognizer.
  Future<bool> startListening({String language = 'en-IN'}) async {
    _currentLanguage = language;
    _lastError = null;
    _lastResults = <String>[];
    _partialText = '';
    _rmsDb = 0.0;
    _updateState(SpeechRecognitionState.ready);

    if (_mockMethodCallHandler != null) {
      final res = await _mockMethodCallHandler!(
        MethodCall('startListening', {'language': language}),
      );
      return res as bool? ?? false;
    }

    try {
      final res = await _channel.invokeMethod<bool>('startListening', {
        'language': language,
      });
      return res ?? false;
    } catch (e) {
      _lastError = e.toString();
      _updateState(SpeechRecognitionState.error);
      return false;
    }
  }

  /// Requests SpeechRecognizer to stop listening.
  Future<bool> stopListening() async {
    if (_mockMethodCallHandler != null) {
      final res = await _mockMethodCallHandler!(const MethodCall('stopListening'));
      return res as bool? ?? false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('stopListening');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels any in-progress speech recognition.
  Future<bool> cancel() async {
    _updateState(SpeechRecognitionState.idle);
    if (_mockMethodCallHandler != null) {
      final res = await _mockMethodCallHandler!(const MethodCall('cancel'));
      return res as bool? ?? false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('cancel');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Manually simulates recognition results.
  void simulateResult(List<String> results) {
    _lastResults = results;
    _partialText = results.isNotEmpty ? results.first : '';
    _resultController.add(results);
    _updateState(SpeechRecognitionState.idle);

    if (_isAlwaysActive && !_isExecutingAction) {
      final match = VoiceNavigationService.instance.parseCandidates(results);
      if (match != null) {
        _triggerCommand(match.command);
      }
    }

    notifyListeners();
  }

  /// Manually simulates partial recognition string.
  void simulatePartial(String text) {
    _partialText = text;
    _partialController.add(text);
    notifyListeners();
  }

  /// Manually simulates RMS audio level.
  void simulateRms(double rms) {
    _rmsDb = rms;
    _rmsController.add(rms);
    notifyListeners();
  }

  /// Manually simulates error.
  void simulateError(String message) {
    _lastError = message;
    _updateState(SpeechRecognitionState.error);
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _actionTimer?.cancel();
    _stateController.close();
    _rmsController.close();
    _partialController.close();
    _resultController.close();
    super.dispose();
  }
}

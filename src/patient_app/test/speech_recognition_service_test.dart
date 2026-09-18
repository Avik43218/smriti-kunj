import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/services/speech_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechRecognitionService Platform Mock Tests', () {
    late SpeechRecognitionService service;
    late List<MethodCall> calls;

    setUp(() {
      service = SpeechRecognitionService.instance;
      calls = <MethodCall>[];

      service.setMockMethodCallHandler((call) async {
        calls.add(call);
        switch (call.method) {
          case 'isAvailable':
            return true;
          case 'hasPermission':
            return true;
          case 'requestPermission':
            return true;
          case 'startListening':
            return true;
          case 'stopListening':
            return true;
          case 'cancel':
            return true;
          default:
            return null;
        }
      });
    });

    test('isAvailable returns true and invokes platform channel', () async {
      final available = await service.isAvailable();
      expect(available, isTrue);
      expect(calls.any((c) => c.method == 'isAvailable'), isTrue);
    });

    test('hasPermission and requestPermission work correctly', () async {
      final hasPerm = await service.hasPermission();
      expect(hasPerm, isTrue);

      final requested = await service.requestPermission();
      expect(requested, isTrue);
    });

    test('startListening sets language and invokes platform channel', () async {
      final started = await service.startListening(language: 'bn-IN');
      expect(started, isTrue);
      expect(service.currentLanguage, 'bn-IN');
      expect(service.state, SpeechRecognitionState.ready);

      final startCall = calls.firstWhere((c) => c.method == 'startListening');
      expect(startCall.arguments['language'], 'bn-IN');
    });

    test('stopListening and cancel invoke appropriate methods', () async {
      await service.stopListening();
      expect(calls.any((c) => c.method == 'stopListening'), isTrue);

      await service.cancel();
      expect(calls.any((c) => c.method == 'cancel'), isTrue);
      expect(service.state, SpeechRecognitionState.idle);
    });

    test('Simulation methods fire streams and update properties', () async {
      expectLater(service.onRmsChanged, emits(8.5));
      service.simulateRms(8.5);
      expect(service.rmsDb, 8.5);

      expectLater(service.onPartialResult, emits('market'));
      service.simulatePartial('market');
      expect(service.partialText, 'market');

      expectLater(service.onResult, emits(['market trip']));
      service.simulateResult(['market trip']);
      expect(service.lastResults, ['market trip']);
      expect(service.state, SpeechRecognitionState.idle);

      service.simulateError('Microphone timeout');
      expect(service.state, SpeechRecognitionState.error);
      expect(service.lastError, 'Microphone timeout');
    });
  });
}

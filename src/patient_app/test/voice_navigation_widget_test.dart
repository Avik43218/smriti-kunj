import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:patient_app/services/locale_service.dart';
import 'package:patient_app/services/session_service.dart';
import 'package:patient_app/services/speech_recognition_service.dart';
import 'package:patient_app/services/voice_navigation_coordinator.dart';
import 'package:patient_app/widgets/voice_nav_button.dart';
import 'package:patient_app/widgets/voice_navigation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SpeechRecognitionService.instance.stopAlwaysActive();
    SpeechRecognitionService.instance.setMockMethodCallHandler((call) async {
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

  Widget buildTestWidget({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SessionService.instance),
        ChangeNotifierProvider.value(value: LocaleService.instance),
        ChangeNotifierProvider.value(value: SpeechRecognitionService.instance),
      ],
      child: MaterialApp(
        navigatorKey: VoiceNavigationCoordinator.navigatorKey,
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  testWidgets('VoiceNavButton renders with semantic label and voice icon', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      child: const VoiceNavButton(size: 76.0),
    ));

    expect(find.byType(VoiceNavButton), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
  });

  testWidgets('VoiceNavButton toggles always-active ON and OFF without opening any pop-up menu', (tester) async {
    final speech = SpeechRecognitionService.instance;
    expect(speech.isAlwaysActive, isFalse);

    await tester.pumpWidget(buildTestWidget(
      child: const VoiceNavButton(size: 76.0),
    ));

    // Tap button to turn ON always active
    await tester.tap(find.byType(VoiceNavButton));
    await tester.pump();

    // Verify microphone is active
    expect(speech.isAlwaysActive, isTrue);
    expect(find.text('Active'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // Verify NO pop-up sheet or dialog was opened
    expect(find.byType(VoiceNavigationSheet), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);

    // Tap button again to turn OFF
    await tester.tap(find.byType(VoiceNavButton));
    await tester.pump();

    // Verify microphone returned to inactive
    expect(speech.isAlwaysActive, isFalse);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('Always-active recognizes commands without opening pop-up', (tester) async {
    final speech = SpeechRecognitionService.instance;
    await speech.startAlwaysActive();
    expect(speech.isAlwaysActive, isTrue);

    await tester.pumpWidget(buildTestWidget(
      child: const VoiceNavButton(size: 76.0),
    ));

    // Simulate speech result in Bengali
    speech.simulateResult(['বাজারের যাত্রা']);
    await tester.pump();

    // Still no modal bottom sheet
    expect(find.byType(VoiceNavigationSheet), findsNothing);
    expect(speech.isAlwaysActive, isTrue);

    await speech.stopAlwaysActive();
    await tester.pump();
  });
}

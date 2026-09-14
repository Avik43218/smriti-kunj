import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/services/session_service.dart';
import 'package:patient_app/widgets/sos_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SOS Button & Guardian Dialer Tests', () {
    testWidgets('SosButton renders with label and telephone icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SosButton(label: 'Help'),
            ),
          ),
        ),
      );

      expect(find.text('Help'), findsOneWidget);
      expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
    });

    testWidgets('SosConfirmationScreen displays guardian contact card and action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SosConfirmationScreen(),
        ),
      );

      // Verify reassuring title and information
      expect(find.text('Help is on the way'), findsOneWidget);
      expect(find.text('Opening your phone dialer to reach your emergency contact.'), findsOneWidget);

      // Check contact card details (defaults or active session values)
      final session = SessionService.instance;
      final expectedName = session.guardianName ?? 'Primary Guardian';
      expect(find.text(expectedName), findsOneWidget);

      // Verify Call Button and Dismiss Button
      expect(find.text('Call $expectedName'), findsOneWidget);
      expect(find.text('I Understand (Back to Home)'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/screens/pairing_screen.dart';
import 'package:patient_app/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PairingScreen displays both Scan QR Code button and Manual Code input',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: patientTheme,
        home: const PairingScreen(),
      ),
    );

    // Verify Title & Subtitles
    expect(find.text('Smriti Kunj'), findsOneWidget);
    expect(find.text('Connect with Caregiver'), findsOneWidget);

    // Verify Scan QR Code button
    final scanQrBtn = find.byKey(const Key('scan_qr_button'));
    expect(scanQrBtn, findsOneWidget);
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

    // Verify Divider / Separator
    expect(find.text('OR ENTER MANUALLY'), findsOneWidget);

    // Verify Manual Pairing Code text field
    final textField = find.byKey(const Key('pairing_code_textfield'));
    expect(textField, findsOneWidget);
    expect(find.text('Pairing Code'), findsOneWidget);

    // Verify Confirm Button
    final confirmBtn = find.byKey(const Key('manual_confirm_button'));
    expect(confirmBtn, findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    // Verify minimum touch target for primary buttons (88dp)
    final scanSize = tester.getSize(scanQrBtn);
    expect(scanSize.height, greaterThanOrEqualTo(88.0));

    final confirmSize = tester.getSize(confirmBtn);
    expect(confirmSize.height, greaterThanOrEqualTo(88.0));
  });

  testWidgets('PairingScreen validates empty or short manual input',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: patientTheme,
        home: const PairingScreen(),
      ),
    );

    // Tap confirm with empty input
    await tester.tap(find.byKey(const Key('manual_confirm_button')));
    await tester.pump();

    // Verify validation message
    expect(find.text('Please enter the pairing code from your caregiver.'), findsOneWidget);

    // Enter short code (2 characters)
    await tester.enterText(find.byKey(const Key('pairing_code_textfield')), '12');
    await tester.tap(find.byKey(const Key('manual_confirm_button')));
    await tester.pump();

    // Verify validation message
    expect(find.text('Please check the code and try again.'), findsOneWidget);
  });
}

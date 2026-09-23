import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/screens/qr_scanner_screen.dart';
import 'package:patient_app/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QrScannerScreen renders header, back button, and fallback manual entry button',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: patientTheme,
        home: const QrScannerScreen(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify top controls: Back button
    expect(find.text('Back'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // Verify top controls: Torch and Flip camera icons
    expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flip_camera_android_rounded), findsOneWidget);

    // Verify bottom prompt and "Enter Code Manually" button
    expect(find.text('Enter Code Manually'), findsWidgets);
    expect(find.byIcon(Icons.keyboard_outlined), findsWidgets);
  });
}

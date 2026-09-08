import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/main.dart';

void main() {
  testWidgets('SmritiSetuApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmritiSetuApp());
    expect(find.text('Smriti Setu'), findsWidgets);
  });
}

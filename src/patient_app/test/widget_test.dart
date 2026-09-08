import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/main.dart';

void main() {
  testWidgets('SmritiKunjApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmritiKunjApp());
    expect(find.text('Smriti Kunj'), findsWidgets);
  });
}

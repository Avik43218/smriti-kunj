import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/theme/theme.dart';
import 'package:patient_app/widgets/app_background.dart';

void main() {
  testWidgets('AppBackground renders child and solid cream base', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppBackground(
          child: Text('Test Content'),
        ),
      ),
    );

    expect(find.text('Test Content'), findsOneWidget);
    // Base ColoredBox with AppColors.cream is present
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == AppColors.cream,
      ),
      findsWidgets,
    );
  });

  testWidgets('AppBackground renders scenery layer with default kSceneryOpacity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppBackground(
          child: Text('Test Content'),
        ),
      ),
    );

    // Scenery image is present
    expect(find.byType(Image), findsOneWidget);
    // Opacity matches kSceneryOpacity (0.12)
    final opacityWidget = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(AppBackground),
        matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == kSceneryOpacity),
      ),
    );
    expect(opacityWidget.opacity, equals(kSceneryOpacity));
  });

  testWidgets('AppBackground respects custom opacity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppBackground(
          opacity: 0.15,
          child: Text('Test Content'),
        ),
      ),
    );

    final opacityWidget = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(AppBackground),
        matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.15),
      ),
    );
    expect(opacityWidget.opacity, equals(0.15));
  });

  testWidgets('AppBackground suppresses scenery when enabled is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppBackground(
          enabled: false,
          child: Text('Test Content'),
        ),
      ),
    );

    expect(find.text('Test Content'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('AppBackground suppresses scenery when high contrast is active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: AppBackground(
            child: Text('Test Content'),
          ),
        ),
      ),
    );

    expect(find.text('Test Content'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}

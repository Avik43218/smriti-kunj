import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/games/shared/models/completion_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('End Screen Warm Completion Variants Tests', () {
    test('CompletionMessage variants list has multiple unique pairs in English and Assamese', () {
      expect(CompletionMessage.variants.length, greaterThanOrEqualTo(5));

      final enHeadings = <String>{};
      final asHeadings = <String>{};
      final enSubheadings = <String>{};
      final asSubheadings = <String>{};

      for (final variant in CompletionMessage.variants) {
        expect(variant.headingEn.trim(), isNotEmpty);
        expect(variant.headingAs.trim(), isNotEmpty);
        expect(variant.subheadingEn.trim(), isNotEmpty);
        expect(variant.subheadingAs.trim(), isNotEmpty);

        enHeadings.add(variant.headingEn);
        asHeadings.add(variant.headingAs);
        enSubheadings.add(variant.subheadingEn);
        asSubheadings.add(variant.subheadingAs);

        // Verify language selector helpers
        expect(variant.heading('en'), equals(variant.headingEn));
        expect(variant.heading('as'), equals(variant.headingAs));
        expect(variant.subheading('en'), equals(variant.subheadingEn));
        expect(variant.subheading('as'), equals(variant.subheadingAs));
      }

      // Verify each variant is unique
      expect(enHeadings.length, equals(CompletionMessage.variants.length));
      expect(asHeadings.length, equals(CompletionMessage.variants.length));
      expect(enSubheadings.length, equals(CompletionMessage.variants.length));
      expect(asSubheadings.length, equals(CompletionMessage.variants.length));
    });

    test('CompletionMessage.getRandom returns valid items', () {
      final random = Random(42);
      for (int i = 0; i < 20; i++) {
        final msg = CompletionMessage.getRandom(random);
        expect(CompletionMessage.variants.contains(msg), isTrue);
      }
    });
  });
}

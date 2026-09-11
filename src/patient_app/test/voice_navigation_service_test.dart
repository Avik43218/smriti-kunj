import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/services/voice_navigation_service.dart';

void main() {
  group('VoiceNavigationService English Parsing Tests', () {
    final parser = VoiceNavigationService.instance;

    test('Parses "Game" and common English variations', () {
      final variations = [
        'Game',
        'game',
        'GAMES',
        'brain games',
        'play game',
        'open games',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.game);
        expect(match.isBengali, isFalse);
        expect(match.confidence, greaterThanOrEqualTo(0.8));
      }
    });

    test('Parses "Market Trip" and common English variations', () {
      final variations = [
        'Market Trip',
        'market trip',
        'The Market Trip',
        'market',
        'shopping list',
        'market game',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.marketTrip);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Tap the target" and common English variations', () {
      final variations = [
        'Tap the target',
        'tap the target',
        'tap target',
        'target',
        'tap the target game',
        'tap game',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.tapTarget);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Pattern match" and common English variations', () {
      final variations = [
        'Pattern match',
        'pattern match',
        'Pattern matching',
        'pair match',
        'pair matching',
        'pattern',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.patternMatch);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Logout" and common English variations', () {
      final variations = [
        'Logout',
        'logout',
        'log out',
        'Sign out',
        'exit',
        'unpair',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.logout);
        expect(match.isBengali, isFalse);
      }
    });
  });

  group('VoiceNavigationService Bengali Parsing Tests', () {
    final parser = VoiceNavigationService.instance;

    test('Parses Bengali "খেলা" (Game) and variations', () {
      final variations = [
        'খেলা',
        'গেম',
        'গেইম',
        'মগজের খেলা',
        'খেলুন',
        'খেলব',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse Bengali: $text');
        expect(match!.command, VoiceCommand.game);
        expect(match.isBengali, isTrue);
      }
    });

    test('Parses Bengali "বাজারের যাত্রা" (Market Trip) and variations', () {
      final variations = [
        'বাজারের যাত্রা',
        'মার্কেট ট্রিপ',
        'বাজার',
        'মার্কেট',
        'বাজারের খেলা',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse Bengali: $text');
        expect(match!.command, VoiceCommand.marketTrip);
        expect(match.isBengali, isTrue);
      }
    });

    test('Parses Bengali "লক্ষ্যে ট্যাপ" (Tap the target) and variations', () {
      final variations = [
        'লক্ষ্যে ট্যাপ',
        'লক্ষ্য ট্যাপ',
        'লক্ষ্যে ট্যাপ করুন',
        'লক্ষ্য',
        'টার্গেট',
        'ট্যাপ দ্য টার্গেট',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse Bengali: $text');
        expect(match!.command, VoiceCommand.tapTarget);
        expect(match.isBengali, isTrue);
      }
    });

    test('Parses Bengali "প্যাটার্ন ম্যাচ" (Pattern match) and variations', () {
      final variations = [
        'প্যাটার্ন ম্যাচ',
        'প্যাটার্ন মিলান',
        'প্যাটার্ন ম্যাচিং',
        'জোড়া মেলানো',
        'জোড়া মিলান',
        'প্যাটার্ন',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse Bengali: $text');
        expect(match!.command, VoiceCommand.patternMatch);
        expect(match.isBengali, isTrue);
      }
    });

    test('Parses Bengali "লগআউট" (Logout) and variations', () {
      final variations = [
        'লগআউট',
        'লগ আউট',
        'প্রস্থান',
        'বের হন',
        'লগআউট করুন',
      ];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse Bengali: $text');
        expect(match!.command, VoiceCommand.logout);
        expect(match.isBengali, isTrue);
      }
    });
  });

  group('Candidate List Evaluation and Fallback Tests', () {
    final parser = VoiceNavigationService.instance;

    test('Selects first matched command from multi-candidate array', () {
      final candidates = ['hello weather', 'play game', 'something else'];
      final match = parser.parseCandidates(candidates);
      expect(match, isNotNull);
      expect(match!.command, VoiceCommand.game);
      expect(match.matchedCandidate, 'play game');
    });

    test('Prioritizes specific game over generic word', () {
      final candidates = ['the market trip'];
      final match = parser.parseCandidates(candidates);
      expect(match, isNotNull);
      expect(match!.command, VoiceCommand.marketTrip);
    });

    test('Returns null for unrelated queries', () {
      final candidates = ['what time is it', 'call doctor', 'show pictures'];
      final match = parser.parseCandidates(candidates);
      expect(match, isNull);
    });
  });

  group('VoiceCommand Metadata & Details Tests', () {
    test('Verifies titles and icons for all commands', () {
      for (final cmd in VoiceCommand.values) {
        expect(cmd.englishTitle.isNotEmpty, isTrue);
        expect(cmd.bengaliTitle.isNotEmpty, isTrue);
        expect(cmd.englishSubtitle.isNotEmpty, isTrue);
        expect(cmd.bengaliSubtitle.isNotEmpty, isTrue);
        expect(cmd.icon, isNotNull);
        expect(cmd.color, isNotNull);
      }
    });
  });
}

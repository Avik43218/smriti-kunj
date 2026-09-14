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

    test('Parses "Home" and English variations', () {
      final variations = ['Home', 'home', 'go home', 'main screen', 'back home'];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.home);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Sync" and English variations', () {
      final variations = ['Sync', 'sync', 'cloud sync', 'sync data', 'backup data'];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.sync);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Help" and English variations', () {
      final variations = ['Help', 'help', 'sos', 'emergency', 'help me'];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.help);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Reminders" and English variations', () {
      final variations = ['Reminders', 'reminders', 'daily reminders', 'notifications', 'alerts'];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.reminders);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses "Memory Gallery" and English variations', () {
      final variations = ['Gallery', 'gallery', 'memory gallery', 'photos', 'pictures'];
      for (final text in variations) {
        final match = parser.parseSingle(text);
        expect(match, isNotNull, reason: 'Failed to parse: $text');
        expect(match!.command, VoiceCommand.gallery);
        expect(match.isBengali, isFalse);
      }
    });

    test('Parses Language Switch commands in English', () {
      expect(parser.parseSingle('language assamese')?.command, VoiceCommand.langAssamese);
      expect(parser.parseSingle('assamese')?.command, VoiceCommand.langAssamese);
      expect(parser.parseSingle('language bengali')?.command, VoiceCommand.langBengali);
      expect(parser.parseSingle('bengali')?.command, VoiceCommand.langBengali);
      expect(parser.parseSingle('language bodo')?.command, VoiceCommand.langBodo);
      expect(parser.parseSingle('bodo')?.command, VoiceCommand.langBodo);
      expect(parser.parseSingle('language english')?.command, VoiceCommand.langEnglish);
      expect(parser.parseSingle('english')?.command, VoiceCommand.langEnglish);
    });
  });

  group('VoiceNavigationService Regional Romanized Phonetic Tests (English Recognizer)', () {
    final parser = VoiceNavigationService.instance;

    test('Parses romanized regional words for Games', () {
      expect(parser.parseSingle('khela')?.command, VoiceCommand.game);
      expect(parser.parseSingle('khel')?.command, VoiceCommand.game);
      expect(parser.parseSingle('geilun')?.command, VoiceCommand.game);
    });

    test('Parses romanized regional words for Home across 4 languages', () {
      // Bengali
      expect(parser.parseSingle('bari')?.command, VoiceCommand.home);
      expect(parser.parseSingle('ghor')?.command, VoiceCommand.home);
      // Assamese
      expect(parser.parseSingle('ghorot')?.command, VoiceCommand.home);
      expect(parser.parseSingle('ghoroloi')?.command, VoiceCommand.home);
      // Bodo
      expect(parser.parseSingle('noh')?.command, VoiceCommand.home);
      expect(parser.parseSingle('nohao')?.command, VoiceCommand.home);
    });

    test('Parses romanized regional words for Sync', () {
      expect(parser.parseSingle('singk')?.command, VoiceCommand.sync);
      expect(parser.parseSingle('sink')?.command, VoiceCommand.sync);
    });

    test('Parses romanized regional words for Help / SOS across 4 languages', () {
      // Bengali
      expect(parser.parseSingle('sahajjo')?.command, VoiceCommand.help);
      // Assamese
      expect(parser.parseSingle('sahay')?.command, VoiceCommand.help);
      // Bodo
      expect(parser.parseSingle('ansunthai')?.command, VoiceCommand.help);
    });

    test('Parses romanized regional words for Reminders across 4 languages', () {
      // Bengali
      expect(parser.parseSingle('osudh')?.command, VoiceCommand.reminders);
      // Assamese
      expect(parser.parseSingle('monot')?.command, VoiceCommand.reminders);
      // Bodo
      expect(parser.parseSingle('goso')?.command, VoiceCommand.reminders);
    });

    test('Parses romanized regional words for Memory Gallery', () {
      // Bengali
      expect(parser.parseSingle('chobi')?.command, VoiceCommand.gallery);
      // Assamese
      expect(parser.parseSingle('sobi')?.command, VoiceCommand.gallery);
      // Bodo
      expect(parser.parseSingle('tasbir')?.command, VoiceCommand.gallery);
    });

    test('Parses regional pronunciation variations for Language switching', () {
      // Assamese variants
      expect(parser.parseSingle('ashamiyo')?.command, VoiceCommand.langAssamese);
      expect(parser.parseSingle('oxomiya')?.command, VoiceCommand.langAssamese);
      expect(parser.parseSingle('asamiya')?.command, VoiceCommand.langAssamese);

      // Bengali variants
      expect(parser.parseSingle('bangla')?.command, VoiceCommand.langBengali);

      // Bodo variants
      expect(parser.parseSingle('boro')?.command, VoiceCommand.langBodo);

      // English variants
      expect(parser.parseSingle('ingreji')?.command, VoiceCommand.langEnglish);
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

    test('Parses Native scripts for Home, Sync, Help, Reminders, Gallery, Languages', () {
      // Home
      expect(parser.parseSingle('বাড়ি')?.command, VoiceCommand.home);
      expect(parser.parseSingle('ঘরে চলো')?.command, VoiceCommand.home);
      expect(parser.parseSingle('ঘৰলৈ')?.command, VoiceCommand.home);

      // Sync
      expect(parser.parseSingle('সিঙ্ক')?.command, VoiceCommand.sync);

      // Help
      expect(parser.parseSingle('সাহায্য')?.command, VoiceCommand.help);
      expect(parser.parseSingle('সহায়')?.command, VoiceCommand.help);
      expect(parser.parseSingle('अनसुंथाय')?.command, VoiceCommand.help);

      // Reminders
      expect(parser.parseSingle('স্মারক')?.command, VoiceCommand.reminders);
      expect(parser.parseSingle('ওষুধের সময়')?.command, VoiceCommand.reminders);

      // Gallery
      expect(parser.parseSingle('ছবি')?.command, VoiceCommand.gallery);
      expect(parser.parseSingle('স্মৃতি গ্যালারি')?.command, VoiceCommand.gallery);

      // Languages
      expect(parser.parseSingle('অসমীয়া')?.command, VoiceCommand.langAssamese);
      expect(parser.parseSingle('বাংলা')?.command, VoiceCommand.langBengali);
      expect(parser.parseSingle('बड़ो')?.command, VoiceCommand.langBodo);
      expect(parser.parseSingle('ইংরেজি')?.command, VoiceCommand.langEnglish);
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
      final candidates = ['what time is it', 'call doctor', 'today weather'];
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

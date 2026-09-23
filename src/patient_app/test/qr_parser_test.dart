import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/utils/qr_parser.dart';

void main() {
  group('QrParser.parsePairingCode', () {
    test('extracts code from smritikunj://pair?code=... deep link', () {
      expect(QrParser.parsePairingCode('smritikunj://pair?code=552785'), '552785');
      expect(QrParser.parsePairingCode('smritikunj://pair?code=PAIR-984210'), '984210');
      expect(QrParser.parsePairingCode('smritikunj://pair?code=ABC123'), 'ABC123');
    });

    test('extracts code from http/https URLs', () {
      expect(QrParser.parsePairingCode('https://smritikunj.app/pair?code=552785'), '552785');
      expect(QrParser.parsePairingCode('http://fedora:8000/pair?pairing_code=PAIR-123456'), '123456');
    });

    test('extracts code from JSON payloads', () {
      expect(QrParser.parsePairingCode('{"code": "552785"}'), '552785');
      expect(QrParser.parsePairingCode('{"pairing_code": "PAIR-984210"}'), '984210');
      expect(QrParser.parsePairingCode('{"token": "ABCD-1234"}'), 'ABCD-1234');
    });

    test('extracts code from raw strings and prefixed strings', () {
      expect(QrParser.parsePairingCode('552785'), '552785');
      expect(QrParser.parsePairingCode('PAIR-552785'), '552785');
      expect(QrParser.parsePairingCode('  pair-984210  '), '984210');
    });

    test('handles path segments when code is in URL path', () {
      expect(QrParser.parsePairingCode('smritikunj://pair/552785'), '552785');
    });

    test('returns null for invalid, empty, or short inputs', () {
      expect(QrParser.parsePairingCode(null), isNull);
      expect(QrParser.parsePairingCode(''), isNull);
      expect(QrParser.parsePairingCode('   '), isNull);
      expect(QrParser.parsePairingCode('12'), isNull); // Too short (< 4 chars)
      expect(QrParser.parsePairingCode('PAIR-'), isNull);
      expect(QrParser.parsePairingCode('invalid@#%'), isNull);
    });
  });
}

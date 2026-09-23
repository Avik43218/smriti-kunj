import 'dart:convert';

/// Utilities to parse and extract patient pairing code from scanned QR codes or deep links.
class QrParser {
  /// Extracts the clean pairing code from raw QR scan data.
  ///
  /// Supported formats:
  /// - Deep link: `smritikunj://pair?code=123456` or `smritikunj://pair?code=PAIR-123456`
  /// - Web link: `https://smritikunj.app/pair?code=123456` or with `pairing_code=...`
  /// - JSON string: `{"code": "123456"}` or `{"pairing_code": "123456"}`
  /// - Raw code: `123456` or `PAIR-123456`
  ///
  /// Returns the cleaned pairing code in uppercase, or `null` if no valid code is found.
  static String? parsePairingCode(String? rawData) {
    if (rawData == null) return null;
    final trimmed = rawData.trim();
    if (trimmed.isEmpty) return null;

    // 1. Check if the string is JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          for (final key in ['code', 'pairing_code', 'pairingCode', 'pair_code', 'token']) {
            final val = decoded[key];
            if (val != null && val.toString().trim().isNotEmpty) {
              return _cleanCode(val.toString());
            }
          }
        }
      } catch (_) {
        // Fall through if not valid JSON
      }
    }

    // 2. Check if the string is a URL / deep link (e.g. smritikunj://pair?code=123456)
    if (trimmed.contains('://') || trimmed.startsWith('smritikunj:')) {
      try {
        final uri = Uri.parse(trimmed);
        final codeParam = uri.queryParameters['code'] ??
            uri.queryParameters['pairing_code'] ??
            uri.queryParameters['pairingCode'] ??
            uri.queryParameters['token'];

        if (codeParam != null && codeParam.trim().isNotEmpty) {
          return _cleanCode(codeParam);
        }

        // If the path itself has segments like /pair/123456
        if (uri.pathSegments.isNotEmpty) {
          final last = uri.pathSegments.last.trim();
          if (last.isNotEmpty && last.toLowerCase() != 'pair') {
            return _cleanCode(last);
          }
        }
      } catch (_) {
        // Fall through
      }
    }

    // 3. Check for query string pattern even if URI scheme was non-standard: `pair?code=123456`
    if (trimmed.contains('code=')) {
      final match = RegExp(r'[?&]code=([A-Za-z0-9\-_]+)').firstMatch(trimmed);
      if (match != null && match.group(1) != null) {
        return _cleanCode(match.group(1)!);
      }
    }

    // 4. Fallback: treat as raw code
    return _cleanCode(trimmed);
  }

  static String? _cleanCode(String value) {
    final clean = value.trim().replaceAll('"', '').replaceAll("'", '');
    if (clean.isEmpty) return null;

    // If formatted as PAIR-XXXXXX or raw alphanumeric
    final upper = clean.toUpperCase();
    final withoutPrefix = upper.startsWith('PAIR-') ? upper.substring(5).trim() : upper;

    // Must be at least 4 characters alphanumeric/hyphen
    if (withoutPrefix.length < 4) return null;

    // Only allow alphanumeric characters and hyphens in the code
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(withoutPrefix)) {
      return null;
    }

    return withoutPrefix;
  }
}

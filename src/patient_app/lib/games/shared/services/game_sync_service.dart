import 'package:flutter/foundation.dart';
import 'game_session_repository.dart';

/// Stub sync service — reads unsynced sessions from [GameSessionRepository]
/// and will POST them to the backend once the API is available.
///
/// Pattern mirrors the caregiver-app's `api.js` stub approach:
/// the method shape and data flow are real; the HTTP call is a placeholder
/// that logs and returns a success stub until the backend is connected.
///
/// To wire the real HTTP call:
/// 1. Uncomment / replace the `// TODO: real HTTP` block in [_postSession].
/// 2. Import `package:http/http.dart` and your auth token provider.
/// 3. Delete the `await Future.delayed(...)` stub line.
class GameSyncService {
  GameSyncService._();
  static final GameSyncService instance = GameSyncService._();

  final GameSessionRepository _repo = GameSessionRepository.instance;

  bool _isSyncing = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Attempts to upload all locally-stored unsynced sessions to the backend.
  ///
  /// - Processes sessions oldest-first (FIFO upload order).
  /// - On success, marks each session as synced in the local DB.
  /// - On failure, logs and stops — will retry on next [syncAll] call.
  /// - Re-entrant safe: concurrent calls are silently skipped.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final unsynced = await _repo.getUnsyncedSessions(limit: 50);
      if (unsynced.isEmpty) {
        debugPrint('[GameSyncService] nothing to sync.');
        return;
      }

      debugPrint(
          '[GameSyncService] syncing ${unsynced.length} session(s)...');

      for (final session in unsynced) {
        final ok = await _postSession(session);
        if (ok) {
          await _repo.markSynced(session.sessionId);
          debugPrint(
              '[GameSyncService] ✓ synced: ${session.sessionId}');
        } else {
          // Stop on first failure — don't skip ahead; order matters for
          // the analytics rolling-baseline calculations on the backend.
          debugPrint(
              '[GameSyncService] ✗ failed: ${session.sessionId} — will retry.');
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Posts a single session envelope to `POST /api/games/sessions`.
  ///
  /// Returns true on success, false on any error.
  ///
  /// STUB: currently simulates success with a short delay.
  /// Replace with real HTTP once the backend is available.
  Future<bool> _postSession(StoredGameSession session) async {
    try {
      // ── Payload shape (proposed contract — pending backend confirmation) ──
      // {
      //   "session_id":         string,
      //   "patient_profile_id": string,
      //   "game_type":          "market_trip"|"tap_target"|"pair_matching",
      //   "domain":             "working_memory"|"episodic_memory"|...,
      //   "session_date":       ISO-8601 string,
      //   "session_duration":   number (seconds),
      //   "status":             "completed"|"abandoned",
      //   "difficulty_level":   int,
      //   "score_normalized":   float (0.0–1.0),
      //   "game_data":          { <game-specific fields — see API_ENDPOINTS_NEEDED.md §5> },
      //   "raw_trials":         [ ... ]
      // }

      final payload = session.toJson()
        ..remove('synced')    // internal flag — not sent to backend
        ..remove('created_at'); // internal field — not sent to backend

      debugPrint('[GameSyncService] payload for ${session.sessionId}: '
          'game_type=${payload['game_type']}, '
          'score=${payload['score_normalized']}');

      // TODO: real HTTP — replace this block when backend is ready:
      // final token = await AuthTokenStore.instance.getToken();
      // final response = await http.post(
      //   Uri.parse('${ApiConfig.baseUrl}/api/games/sessions'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: json.encode(payload),
      // );
      // return response.statusCode == 200 || response.statusCode == 201;

      // ── STUB: simulate a successful POST ──────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 50));
      return true;
      // ─────────────────────────────────────────────────────────────────────
    } catch (e) {
      debugPrint('[GameSyncService] _postSession error: $e');
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:patient_app/models/patient_activity.dart';
import 'package:patient_app/screens/home_screen.dart';
import 'package:patient_app/services/locale_service.dart';
import 'package:patient_app/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PatientActivityRecord & Sync Payload Isolation Tests', () {
    test('PatientActivityRecord persists pairingCode in toMap and restores in fromMap', () {
      final now = DateTime.now();
      final record = PatientActivityRecord(
        clientSessionId: 'test_session_101',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'market_trip',
        gameName: 'Market Trip',
        domain: 'memory',
        difficultyLevel: 2,
        scoreNormalized: 0.88,
        sessionDuration: 95,
        accuracy: 0.90,
        avgLatencyMs: 1250.0,
        errorRate: 0.10,
        sessionDate: now,
        rawPayload: {'items_recalled': 4},
      );

      final map = record.toMap();
      expect(map['pairing_code'], 'PAIR-652759');
      expect(map['client_session_id'], 'test_session_101');
      expect(map['patient_id'], 'p101');

      final restored = PatientActivityRecord.fromMap(map);
      expect(restored.pairingCode, 'PAIR-652759');
      expect(restored.clientSessionId, 'test_session_101');
      expect(restored.patientId, 'p101');
      expect(restored.gameType, 'market_trip');
      expect(restored.scoreNormalized, 0.88);
    });

    test('PatientActivityRecord toSyncBatchJson strictly OMITS pairing_code for MongoDB transfer', () {
      final record = PatientActivityRecord(
        clientSessionId: 'sync_test_202',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'tap_target',
        gameName: 'Tap Target',
        domain: 'attention',
        difficultyLevel: 1,
        scoreNormalized: 0.92,
        sessionDuration: 60,
        accuracy: 0.95,
        avgLatencyMs: 850.0,
        errorRate: 0.05,
        sessionDate: DateTime.now(),
      );

      final syncJson = record.toSyncBatchJson();

      // Ensure game activity data is present
      expect(syncJson['client_session_id'], 'sync_test_202');
      expect(syncJson['game_type'], 'tap_target');
      expect(syncJson['accuracy'], 0.95);
      expect(syncJson['score_normalized'], 0.92);

      // CRITICAL REQUIREMENT: pairing_code must NOT be sent to MongoDB in game activity payload
      expect(syncJson.containsKey('pairing_code'), isFalse);
      expect(syncJson.containsKey('pairingCode'), isFalse);
      final rawPayload = syncJson['raw_payload'] as Map?;
      expect(rawPayload?.containsKey('pairing_code'), isFalse);
    });

    test('PatientActivityRecord copyWith preserves or updates pairingCode', () {
      final record = PatientActivityRecord(
        clientSessionId: 'copy_test_303',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: null,
        gameType: 'pair_matching',
        gameName: 'Pair Matching',
        domain: 'memory',
        difficultyLevel: 1,
        scoreNormalized: 0.75,
        sessionDuration: 80,
        accuracy: 0.80,
        avgLatencyMs: 1500.0,
        errorRate: 0.20,
        sessionDate: DateTime.now(),
      );

      expect(record.pairingCode, isNull);

      final updated = record.copyWith(pairingCode: 'PAIR-123456');
      expect(updated.pairingCode, 'PAIR-123456');
      expect(updated.clientSessionId, record.clientSessionId);
    });
  });

  group('SessionService Auto-Login, Guardian Phone, and Unpair State Tests', () {
    test('SessionService pairs device, extracts guardian phone and updates state', () async {
      final session = SessionService.instance;
      // Pairing with valid demo code
      final success = await session.pairDevice('PAIR-652759');
      expect(success, isTrue);
      expect(session.isPaired, isTrue);
      expect(session.pairingCode, 'PAIR-652759');
      expect(session.patientId, 'p101');
      expect(session.guardianPhone, isNotNull);
      expect(session.guardianPhone, contains('98765'));
      expect(session.guardianName, 'Priya Sharma');
    });

    test('SessionService unpair resets state and guardian phone completely', () async {
      final session = SessionService.instance;
      await session.pairDevice('PAIR-652759');
      expect(session.isPaired, isTrue);
      expect(session.guardianPhone, isNotNull);

      await session.unpair();
      expect(session.isPaired, isFalse);
      expect(session.pairingCode, isNull);
      expect(session.authToken, isNull);
      expect(session.guardianPhone, isNull);
      expect(session.guardianName, isNull);
      expect(session.guardianRelationship, isNull);
      expect(session.currentSession, isNull);
    });

    test('SessionService rejects empty pairing code', () async {
      final session = SessionService.instance;
      final success = await session.pairDevice('   ');
      expect(success, isFalse);
      expect(session.errorMessage, contains('valid pairing code'));
    });
  });

  group('Sync Pairing Code Association Filter Tests', () {
    test('Filters and validates activities matching active pairing code', () {
      const activeCode = 'PAIR-652759';

      final matchingActivity = PatientActivityRecord(
        clientSessionId: 'valid_sess',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'market_trip',
        gameName: 'Market Trip',
        domain: 'memory',
        difficultyLevel: 1,
        scoreNormalized: 0.85,
        sessionDuration: 90,
        accuracy: 0.90,
        avgLatencyMs: 1200.0,
        errorRate: 0.10,
        sessionDate: DateTime.now(),
      );

      final mismatchedActivity = PatientActivityRecord(
        clientSessionId: 'invalid_sess',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-WRONG999',
        gameType: 'tap_target',
        gameName: 'Tap Target',
        domain: 'attention',
        difficultyLevel: 1,
        scoreNormalized: 0.70,
        sessionDuration: 50,
        accuracy: 0.75,
        avgLatencyMs: 1400.0,
        errorRate: 0.25,
        sessionDate: DateTime.now(),
      );

      final activities = [matchingActivity, mismatchedActivity];

      // Simulated sync validation rule
      final validToSync = activities.where((act) => act.pairingCode == activeCode).toList();

      expect(validToSync.length, 1);
      expect(validToSync.first.clientSessionId, 'valid_sess');
    });
  });

  group('Top-Right Dropdown Menu Widget Tests', () {
    testWidgets('HomeScreen displays dropdown menu with Sound and Log Out items', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final session = SessionService.instance;
      // Ensure paired for HomeScreen display
      await session.pairDevice('PAIR-652759');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: session),
            ChangeNotifierProvider.value(value: LocaleService.instance),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the top-right menu button is present
      final menuButtonFinder = find.byIcon(Icons.more_vert_rounded);
      expect(menuButtonFinder, findsOneWidget);

      // Open the dropdown menu
      await tester.tap(menuButtonFinder);
      await tester.pumpAndSettle();

      // Verify both Sound and Log Out options are in the dropdown
      expect(find.textContaining('Sound'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Tap Log Out option — instantly logs out and switches to PairingScreen
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      // Verify screen instantly switched to the "Enter pairing code" screen
      expect(find.text('Connect with Caregiver'), findsOneWidget);
      expect(find.text('Pairing Code'), findsOneWidget);

      // Verify session is unpaired
      expect(session.isPaired, isFalse);
      expect(session.pairingCode, isNull);
    });
  });
}

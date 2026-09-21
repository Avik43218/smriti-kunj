import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:patient_app/models/patient_profile_status.dart';
import 'package:patient_app/screens/home_screen.dart';
import 'package:patient_app/screens/profile_status_screen.dart';
import 'package:patient_app/services/activity_database_service.dart';
import 'package:patient_app/services/locale_service.dart';
import 'package:patient_app/services/session_service.dart';

/// Mock implementation of [UrlLauncherPlatform] for testing dial pad actions and fallbacks.
class MockUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;
  LaunchOptions? launchOptions;
  bool canLaunchReturnValue = true;
  bool launchReturnValue = true;

  @override
  Future<bool> canLaunch(String url) async => canLaunchReturnValue;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchOptions = options;
    return launchReturnValue;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockUrlLauncherPlatform mockUrlLauncher;

  setUp(() {
    mockUrlLauncher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockUrlLauncher;
  });

  group('ProfileEmergencyContact & PatientProfileStatus Model Tests', () {
    test('normalizedDialNumber preserves + and strips spaces, hyphens, and brackets', () {
      const contact1 = ProfileEmergencyContact(
        type: 'primary',
        name: 'Arup Saikia',
        relationship: 'Son',
        phone: '+91 (987) 654-3210',
      );
      expect(contact1.normalizedDialNumber, '+919876543210');

      const contact2 = ProfileEmergencyContact(
        type: 'alternative',
        name: 'Mitali Barman',
        relationship: 'Daughter',
        phone: '09876 543 210',
      );
      expect(contact2.normalizedDialNumber, '09876543210');
    });

    test('formattedDisplayNumber formats Indian numbers with readable grouping', () {
      const contact1 = ProfileEmergencyContact(
        type: 'primary',
        name: 'Arup Saikia',
        relationship: 'Son',
        phone: '+919876543210',
      );
      expect(contact1.formattedDisplayNumber, '+91 98765 43210');

      const contact2 = ProfileEmergencyContact(
        type: 'alternative',
        name: 'Mitali Barman',
        relationship: 'Daughter',
        phone: '9876543210',
      );
      expect(contact2.formattedDisplayNumber, '98765 43210');
    });

    test('screenReaderSpokenDigits spaces every digit for calm, non-rushed screen-reader pronunciation', () {
      const contact = ProfileEmergencyContact(
        type: 'primary',
        name: 'Arup Saikia',
        relationship: 'Son',
        phone: '+919876543210',
      );
      expect(contact.screenReaderSpokenDigits, '+ 9 1 9 8 7 6 5 4 3 2 1 0');
    });

    test('PatientProfileStatus serializes and deserializes correctly', () {
      final status = PatientProfileStatus(
        patientName: 'Bipul Bora',
        caregiverNames: const ['Dr. Ananya Sharma', 'Mitali Barman'],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Arup Saikia',
            relationship: 'Son',
            phone: '+919876543210',
          ),
          ProfileEmergencyContact(
            type: 'alternative',
            name: 'Sunita Das',
            relationship: 'Neighbour',
            phone: '+919876500000',
          ),
        ],
        lastUpdated: DateTime.parse('2026-03-20T10:00:00.000Z'),
      );

      final json = status.toJson();
      final revived = PatientProfileStatus.fromJson(json);

      expect(revived.patientName, 'Bipul Bora');
      expect(revived.caregiverDisplayName, 'Dr. Ananya Sharma, Mitali Barman');
      expect(revived.primaryContact?.name, 'Arup Saikia');
      expect(revived.alternativeContact?.name, 'Sunita Das');
      expect(revived.contacts.length, 2);
    });
  });

  group('ActivityDatabaseService Profile Status SQLite Persistence', () {
    late Database inMemoryDb;
    late ActivityDatabaseService activityDb;

    setUp(() async {
      inMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await inMemoryDb.execute('''
        CREATE TABLE app_pairing_code (
          id                    INTEGER PRIMARY KEY AUTOINCREMENT,
          pairing_code          TEXT    NOT NULL UNIQUE,
          patient_id            TEXT,
          saved_at              TEXT    NOT NULL,
          is_active             INTEGER NOT NULL DEFAULT 1,
          guardian_phone        TEXT,
          guardian_name         TEXT,
          guardian_relationship TEXT
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE patient_diagnosis (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id   TEXT NOT NULL UNIQUE,
          diagnosis    TEXT NOT NULL,
          updated_at   TEXT NOT NULL
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE patient_memories (
          id               TEXT PRIMARY KEY,
          patient_id       TEXT NOT NULL,
          title            TEXT NOT NULL,
          subtitle         TEXT,
          relationship     TEXT,
          type             TEXT NOT NULL,
          photo_url        TEXT,
          audio_url        TEXT,
          duration         TEXT,
          audio_duration   TEXT,
          placeholder_icon TEXT,
          accent_color     INTEGER,
          created_at       TEXT
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE patient_profile_status (
          id                    INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id            TEXT,
          pairing_code          TEXT,
          patient_name          TEXT NOT NULL,
          caregivers_json       TEXT,
          contacts_json         TEXT,
          last_updated          TEXT NOT NULL
        )
      ''');

      activityDb = ActivityDatabaseService.instance;
      activityDb.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() async {
      activityDb.setDatabaseForTesting(null);
      await inMemoryDb.close();
    });

    test('saveProfileStatus and getProfileStatus correctly persist and restore profile data', () async {
      final status = PatientProfileStatus(
        patientName: 'Pratibha Devi',
        caregiverNames: const ['Rani Devi'],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Arup Saikia',
            relationship: 'Son',
            phone: '+919876543210',
          ),
        ],
        lastUpdated: DateTime.now(),
      );

      await activityDb.saveProfileStatus(status, patientId: 'patient_789');

      final retrieved = await activityDb.getProfileStatus(patientId: 'patient_789');
      expect(retrieved, isNotNull);
      expect(retrieved!.patientName, 'Pratibha Devi');
      expect(retrieved.caregiverDisplayName, 'Rani Devi');
      expect(retrieved.contacts.length, 1);
      expect(retrieved.primaryContact?.phone, '+919876543210');
    });

    test('clearSavedPairingCode clears profile status along with pairing code', () async {
      await activityDb.savePairingCode('PAIR-999999', patientId: 'patient_789');
      final status = PatientProfileStatus(
        patientName: 'Pratibha Devi',
        caregiverNames: const [],
        emergencyContacts: const [],
        lastUpdated: DateTime.now(),
      );
      await activityDb.saveProfileStatus(status, patientId: 'patient_789');

      expect(await activityDb.getProfileStatus(patientId: 'patient_789'), isNotNull);

      await activityDb.clearSavedPairingCode();

      expect(await activityDb.getProfileStatus(patientId: 'patient_789'), isNull);
    });
  });

  group('HomeScreen Three-Dot Menu & ProfileStatusScreen Widget Tests', () {
    testWidgets('Three-dot menu replaces Sounds with Profile Status and navigates to ProfileStatusScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final session = SessionService.instance;
      session.setPairedForTesting('PAIR-652759');

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

      // Tap the three-dot more menu
      final menuButtonFinder = find.byIcon(Icons.more_vert_rounded);
      expect(menuButtonFinder, findsOneWidget);
      await tester.tap(menuButtonFinder);
      await tester.pumpAndSettle();

      // Verify "Profile Status" is shown and "Sounds" is absent
      expect(find.text('Profile Status'), findsOneWidget);
      expect(find.text('Sounds'), findsNothing);
      expect(find.text('Sound'), findsNothing);

      // Tap "Profile Status"
      await tester.tap(find.text('Profile Status'));
      await tester.pumpAndSettle();

      // Verify navigation to ProfileStatusScreen
      expect(find.byType(ProfileStatusScreen), findsOneWidget);
      expect(find.text('Profile Status'), findsWidgets);
    });

    testWidgets('ProfileStatusScreen displays patient name, caregivers, and primary contact', (tester) async {
      final status = PatientProfileStatus(
        patientName: 'Bipul Bora',
        caregiverNames: const ['Dr. Ananya Sharma', 'Rani Saikia'],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Arup Saikia',
            relationship: 'Son',
            phone: '+919876543210',
          ),
        ],
        lastUpdated: DateTime(2026, 3, 20, 14, 30),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: LocaleService.instance,
          child: MaterialApp(
            home: ProfileStatusScreen(initialStatus: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Patient Name and Avatar
      expect(find.text('Bipul Bora'), findsOneWidget);
      expect(find.text('B'), findsOneWidget); // Initials avatar

      // Caregivers Display Names
      expect(find.text('Dr. Ananya Sharma'), findsOneWidget);
      expect(find.text('Rani Saikia'), findsOneWidget);

      // Primary Contact Card
      expect(find.text('Arup Saikia'), findsOneWidget);
      expect(find.text('Son'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);

      // Alternative badge should not be present since no alternative contact exists
      expect(find.text('Alternative'), findsNothing);

      // Reassurance text
      expect(
        find.text('To change these details, ask your caregiver.'),
        findsOneWidget,
      );
    });

    testWidgets('ProfileStatusScreen displays alternative contact only when present', (tester) async {
      final status = PatientProfileStatus(
        patientName: 'Bipul Bora',
        caregiverNames: const ['Rani Saikia'],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Arup Saikia',
            relationship: 'Son',
            phone: '+919876543210',
          ),
          ProfileEmergencyContact(
            type: 'alternative',
            name: 'Sunita Das',
            relationship: 'Daughter',
            phone: '+919876500000',
          ),
        ],
        lastUpdated: DateTime(2026, 3, 20, 14, 30),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: LocaleService.instance,
          child: MaterialApp(
            home: ProfileStatusScreen(initialStatus: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both contacts rendered
      expect(find.text('Arup Saikia'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);

      expect(find.text('Sunita Das'), findsOneWidget);
      expect(find.text('Daughter'), findsOneWidget);
      expect(find.text('Alternative'), findsOneWidget);
    });

    testWidgets('Tapping emergency contact card launches dial pad with tel: URI', (tester) async {
      mockUrlLauncher.canLaunchReturnValue = true;
      mockUrlLauncher.launchReturnValue = true;

      final status = PatientProfileStatus(
        patientName: 'Bipul Bora',
        caregiverNames: const ['Rani Saikia'],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Arup Saikia',
            relationship: 'Son',
            phone: '+91 98765-43210',
          ),
        ],
        lastUpdated: DateTime.now(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: LocaleService.instance,
          child: MaterialApp(
            home: ProfileStatusScreen(initialStatus: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the emergency contact card
      final cardFinder = find.text('Arup Saikia');
      expect(cardFinder, findsOneWidget);
      await tester.tap(cardFinder);
      await tester.pump();

      // Verify that url_launcher was called with the normalized tel: URI
      expect(mockUrlLauncher.launchedUrl, 'tel:+919876543210');
      expect(
        mockUrlLauncher.launchOptions?.mode,
        PreferredLaunchMode.externalApplication,
      );
    });

    testWidgets('When dialer launch is unsupported (e.g. tablet), shows accessible fallback dialog with copy action',
        (tester) async {
      // Simulate tablet without phone dialer
      mockUrlLauncher.canLaunchReturnValue = false;

      final status = PatientProfileStatus(
        patientName: 'Bipul Bora',
        caregiverNames: const ['Rani Saikia'],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Arup Saikia',
            relationship: 'Son',
            phone: '+919876543210',
          ),
        ],
        lastUpdated: DateTime.now(),
      );

      // Track clipboard data
      String? clipboardValue;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map;
            clipboardValue = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: LocaleService.instance,
          child: MaterialApp(
            home: ProfileStatusScreen(initialStatus: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on emergency contact card
      await tester.tap(find.text('Arup Saikia'));
      await tester.pumpAndSettle();

      // Fallback modal dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining("This tablet can't make calls"),
        findsOneWidget,
      );
      expect(find.text('+91 98765 43210'), findsWidgets);
      expect(find.text('Copy number'), findsOneWidget);

      // Tap "Copy number"
      await tester.tap(find.text('Copy number'));
      await tester.pumpAndSettle();

      // Verify number was copied to clipboard
      expect(clipboardValue, '+919876543210');

      // Verify dialog dismissed and snackbar shown
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Number copied'), findsOneWidget);
    });

    testWidgets('ProfileStatusScreen displays caregiver phone number and allows tap-to-dial', (tester) async {
      mockUrlLauncher.canLaunchReturnValue = true;
      mockUrlLauncher.launchReturnValue = true;

      final status = PatientProfileStatus(
        patientName: 'Ayeshika Dutta',
        caregivers: const [
          CaregiverContact(
            name: 'Priya Dutta',
            phone: '+91 9123457689',
            isPrimary: true,
          ),
        ],
        emergencyContacts: const [],
        lastUpdated: DateTime.now(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: LocaleService.instance,
          child: MaterialApp(
            home: ProfileStatusScreen(initialStatus: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check caregiver card components
      expect(find.text('Priya Dutta'), findsOneWidget);
      expect(find.text('+91 91234 57689'), findsOneWidget);
      expect(find.text('Caregiver'), findsOneWidget);
      expect(find.text('Tap to open dial pad'), findsOneWidget);

      // Tap caregiver card
      await tester.tap(find.text('Priya Dutta'));
      await tester.pump();

      // Verify that url_launcher was called with the normalized caregiver tel: URI
      expect(mockUrlLauncher.launchedUrl, 'tel:+919123457689');
      expect(
        mockUrlLauncher.launchOptions?.mode,
        PreferredLaunchMode.externalApplication,
      );
    });
  });
}

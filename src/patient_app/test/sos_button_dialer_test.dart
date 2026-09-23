import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/models/patient_profile_status.dart';
import 'package:patient_app/services/locale_service.dart';
import 'package:patient_app/services/session_service.dart';
import 'package:patient_app/widgets/sos_button.dart';

Widget createSosTestApp(Widget child, {AppLang lang = AppLang.english}) {
  final locale = LocaleService.instance;
  locale.setLang(lang);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: SessionService.instance),
      ChangeNotifierProvider.value(value: locale),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SessionService.instance.unpair();
  });

  group('SOS Button & Caregiver Dialer Tests', () {
    testWidgets('SosButton renders with label and telephone icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        createSosTestApp(
          const Scaffold(
            body: Center(
              child: SosButton(label: 'Help'),
            ),
          ),
        ),
      );

      expect(find.text('Help'), findsOneWidget);
      expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
    });

    testWidgets('SosConfirmationScreen displays caregiver contact card when caregiver phone is present (Priority 1)',
        (WidgetTester tester) async {
      SessionService.instance.setPairedForTesting(
        'TEST01',
        patientName: 'Aarav Sharma',
        caregiverName: 'Priya Sharma',
        caregiverPhone: '+919876543210',
        guardianName: 'Dr. Barua',
        guardianPhone: '+919876543211',
      );

      await tester.pumpWidget(
        createSosTestApp(
          const SosConfirmationScreen(),
        ),
      );

      // Verify reassuring title and caregiver-specific intro
      expect(find.text('Help is on the way'), findsOneWidget);
      expect(find.text('Opening your phone dialer to reach your caregiver.'), findsOneWidget);

      // Check caregiver contact card details
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Caregiver'), findsOneWidget);

      // Verify Call Button with caregiver name and Dismiss Button
      expect(find.text('Call Priya Sharma'), findsOneWidget);
      expect(find.text('I Understand (Back to Home)'), findsOneWidget);
      // Copy icon is available
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('SosConfirmationScreen falls back to secondary caregiver (Priority 2)',
        (WidgetTester tester) async {
      final profile = PatientProfileStatus(
        patientName: 'Aarav Sharma',
        caregivers: const [
          CaregiverContact(name: 'Primary CG Without Phone', phone: null, isPrimary: true),
          CaregiverContact(name: 'Anjali Sharma', phone: '+919876543299', isPrimary: false),
        ],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Emergency Person',
            relationship: 'Neighbor',
            phone: '+919876543200',
          ),
        ],
      );

      SessionService.instance.setPairedForTesting(
        'TEST02',
        patientName: 'Aarav Sharma',
        profileStatus: profile,
      );

      await tester.pumpWidget(
        createSosTestApp(
          const SosConfirmationScreen(),
        ),
      );

      // Should prioritize secondary caregiver over emergency contact
      expect(find.text('Anjali Sharma'), findsOneWidget);
      expect(find.text('Call Anjali Sharma'), findsOneWidget);
    });

    testWidgets('SosConfirmationScreen falls back to primary emergency contact if no caregiver phone (Priority 3)',
        (WidgetTester tester) async {
      final profile = PatientProfileStatus(
        patientName: 'Aarav Sharma',
        caregivers: const [
          CaregiverContact(name: 'Caregiver No Phone', phone: null, isPrimary: true),
        ],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Vikram Das',
            relationship: 'Brother',
            phone: '+919876543233',
          ),
        ],
      );

      SessionService.instance.setPairedForTesting(
        'TEST03',
        patientName: 'Aarav Sharma',
        profileStatus: profile,
      );

      await tester.pumpWidget(
        createSosTestApp(
          const SosConfirmationScreen(),
        ),
      );

      // Intro mentions caregiver
      expect(find.text('Opening your phone dialer to reach your caregiver.'), findsOneWidget);
      expect(find.text('Vikram Das'), findsOneWidget);
      expect(find.text('Call Vikram Das'), findsOneWidget);
    });

    testWidgets('SosConfirmationScreen falls back to alternative contact (Priority 4)',
        (WidgetTester tester) async {
      final profile = PatientProfileStatus(
        patientName: 'Aarav Sharma',
        caregivers: const [],
        emergencyContacts: const [
          ProfileEmergencyContact(
            type: 'primary',
            name: 'Primary No Phone',
            relationship: 'Friend',
            phone: '',
          ),
          ProfileEmergencyContact(
            type: 'alternative',
            name: 'Dr. Sen',
            relationship: 'Doctor',
            phone: '+919876543244',
          ),
        ],
      );

      SessionService.instance.setPairedForTesting(
        'TEST04',
        patientName: 'Aarav Sharma',
        profileStatus: profile,
      );

      await tester.pumpWidget(
        createSosTestApp(
          const SosConfirmationScreen(),
        ),
      );

      expect(find.text('Dr. Sen'), findsOneWidget);
      expect(find.text('Call Dr. Sen'), findsOneWidget);
    });

    testWidgets('SosConfirmationScreen displays calm empty state when no phone is saved anywhere (Priority 5)',
        (WidgetTester tester) async {
      SessionService.instance.setPairedForTesting(
        'EMPTY',
        patientName: 'Aarav Sharma',
        caregiverName: 'Caregiver With No Phone',
        caregiverPhone: null,
        guardianPhone: null,
      );

      await tester.pumpWidget(
        createSosTestApp(
          const SosConfirmationScreen(),
        ),
      );

      // Calm empty state elements
      expect(find.text('No phone number saved yet'), findsOneWidget);
      expect(find.text('Please ask your caregiver to add a phone number.'), findsOneWidget);
      expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
      expect(find.text('I Understand (Back to Home)'), findsOneWidget);
      // No call button in empty state
      expect(find.byIcon(Icons.phone_forwarded_rounded), findsNothing);
    });

    testWidgets('SosConfirmationScreen supports regional languages (Assamese)',
        (WidgetTester tester) async {
      SessionService.instance.setPairedForTesting(
        'LANG_TEST',
        patientName: 'Aarav Sharma',
        caregiverName: 'Priya Sharma',
        caregiverPhone: '+919876543210',
      );

      await tester.pumpWidget(
        createSosTestApp(
          const SosConfirmationScreen(),
          lang: AppLang.assamese,
        ),
      );

      // Assamese header & strings
      expect(find.text('সহায় আহি আছে'), findsOneWidget);
      expect(find.text('পৰিচর্যাকাৰী'), findsOneWidget);
      expect(find.text('Priya Sharma-লৈ কল কৰক'), findsOneWidget);
    });

    test('launchGuardianDialer and launchCaregiverDialer handle missing phone gracefully', () async {
      SessionService.instance.unpair();
      final result1 = await launchCaregiverDialer();
      expect(result1, isFalse);

      final result2 = await launchGuardianDialer();
      expect(result2, isFalse);
    });
  });
}

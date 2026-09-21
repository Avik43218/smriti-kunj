import 'package:flutter/foundation.dart';
import '../models/patient_diagnosis.dart';
import '../models/patient_profile_status.dart';
import '../models/patient_session.dart';
import 'activity_database_service.dart';
import 'api_service.dart';

/// Target contact resolved for emergency SOS calling via 5-tier fallback.
class SosTarget {
  final String name;
  final String? phone;
  final String relationship;
  final int priority; // 1: Primary Caregiver, 2: Secondary Caregiver, 3: Primary Emergency Contact, 4: Alternative Emergency Contact, 5: None

  const SosTarget({
    required this.name,
    this.phone,
    required this.relationship,
    required this.priority,
  });

  bool get hasValidPhone => phone != null && phone!.trim().isNotEmpty;
  bool get isCaregiver => priority == 1 || priority == 2;
  bool get isEmergencyContact => priority == 3 || priority == 4;
  bool get isEmpty => priority == 5 || !hasValidPhone;

  String? get normalizedPhone {
    if (!hasValidPhone) return null;
    final clean = phone!.replaceAll(RegExp(r'[^\d]'), '');
    return phone!.trim().startsWith('+') ? '+$clean' : clean;
  }

  String? get formattedPhone {
    final clean = normalizedPhone;
    if (clean == null || clean.isEmpty) return null;
    if (clean.startsWith('+91') && clean.length == 13) {
      return '+91 ${clean.substring(3, 8)} ${clean.substring(8)}';
    } else if (clean.length == 10 && !clean.startsWith('+')) {
      return '${clean.substring(0, 5)} ${clean.substring(5)}';
    } else if (clean.length > 7) {
      final hasPlus = clean.startsWith('+');
      final digits = hasPlus ? clean.substring(1) : clean;
      final mid = digits.length ~/ 2;
      return '${hasPlus ? '+' : ''}${digits.substring(0, mid)} ${digits.substring(mid)}';
    }
    return clean;
  }
}

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();

  SessionService._internal();
  factory SessionService() => instance;

  bool _isPaired = false;
  bool _isInitializing = false;
  String? _pairingCode;
  String _patientId = 'p101';
  String _patientCode = 'p101';
  String _patientName = 'Aarav Sharma';
  String? _authToken;
  String? _caregiverId;
  String _regionLanguage = 'bn';
  Map<String, dynamic>? _emergencyContact;
  String? _guardianPhone;
  String? _guardianName;
  String? _guardianRelationship;
  String? _caregiverPhone;
  String? _caregiverName;
  List<CaregiverContact> _caregivers = [];
  PatientProfileStatus? _cachedProfileStatus;
  PatientSession? _currentSession;
  PatientDiagnosisInfo? _diagnosisInfo;
  String? _errorMessage;

  bool get isPaired => _isPaired;
  bool get isInitializing => _isInitializing;
  String? get pairingCode => _pairingCode;
  String get patientId => _patientId;
  String get patientCode => _patientCode;
  String get patientName => _patientName;
  String? get authToken => _authToken;
  String? get caregiverId => _caregiverId;
  String get regionLanguage => _regionLanguage;
  Map<String, dynamic>? get emergencyContact => _emergencyContact;
  String? get guardianPhone => _guardianPhone;
  String? get guardianName => _guardianName;
  String? get guardianRelationship => _guardianRelationship;
  String? get caregiverPhone => _caregiverPhone;
  String? get caregiverName => _caregiverName;
  List<CaregiverContact> get caregivers => _caregivers;
  PatientProfileStatus? get cachedProfileStatus => _cachedProfileStatus;
  PatientSession? get currentSession => _currentSession;
  PatientDiagnosisInfo? get diagnosisInfo => _diagnosisInfo;
  String? get diagnosis => _diagnosisInfo?.rawDiagnosis ?? _currentSession?.diagnosis;
  int get diagnosisPriorityNumber => _diagnosisInfo?.priorityNumber ?? 7;
  String? get errorMessage => _errorMessage;

  /// Resolves the active SOS contact target following the 5-tier fallback priority chain:
  /// 1. Primary assigned caregiver phone
  /// 2. Secondary assigned caregiver phone
  /// 3. Primary emergency contact phone
  /// 4. Alternative emergency contact phone
  /// 5. Empty target (no phone number found)
  SosTarget get activeSosTarget {
    final prof = _cachedProfileStatus;

    // 1. Primary assigned caregiver
    if (prof != null && prof.caregivers.isNotEmpty) {
      final primary = prof.primaryCaregiver;
      if (primary != null && primary.phone != null && primary.phone!.trim().isNotEmpty) {
        return SosTarget(
          name: primary.name,
          phone: primary.phone,
          relationship: 'Caregiver',
          priority: 1,
        );
      }
    }
    if (_caregiverPhone != null && _caregiverPhone!.trim().isNotEmpty) {
      return SosTarget(
        name: _caregiverName ?? 'Caregiver',
        phone: _caregiverPhone,
        relationship: 'Caregiver',
        priority: 1,
      );
    }

    // 2. Secondary assigned caregivers
    if (prof != null) {
      for (final cg in prof.caregivers) {
        if (!cg.isPrimary && cg.phone != null && cg.phone!.trim().isNotEmpty) {
          return SosTarget(
            name: cg.name,
            phone: cg.phone,
            relationship: 'Caregiver',
            priority: 2,
          );
        }
      }
    }

    // 3. Primary contact / guardian fallback (treated as Caregiver)
    if (_guardianPhone != null && _guardianPhone!.trim().isNotEmpty) {
      return SosTarget(
        name: _guardianName ?? 'Caregiver',
        phone: _guardianPhone,
        relationship: 'Caregiver',
        priority: 1,
      );
    }
    final primaryEc = prof?.primaryContact;
    if (primaryEc != null && primaryEc.phone.trim().isNotEmpty) {
      return SosTarget(
        name: primaryEc.name,
        phone: primaryEc.phone,
        relationship: 'Caregiver',
        priority: 1,
      );
    }
    if (_emergencyContact != null &&
        _emergencyContact!['phone'] != null &&
        _emergencyContact!['phone'].toString().trim().isNotEmpty) {
      return SosTarget(
        name: _emergencyContact!['name']?.toString() ?? 'Caregiver',
        phone: _emergencyContact!['phone'].toString(),
        relationship: 'Caregiver',
        priority: 1,
      );
    }

    // 4. Alternative emergency contact
    final altEc = prof?.alternativeContact;
    if (altEc != null && altEc.phone.trim().isNotEmpty) {
      return SosTarget(
        name: altEc.name,
        phone: altEc.phone,
        relationship: altEc.relationship.isNotEmpty ? altEc.relationship : 'Alternative Contact',
        priority: 4,
      );
    }

    // 5. None
    return const SosTarget(
      name: '',
      phone: null,
      relationship: '',
      priority: 5,
    );
  }

  void updateCachedProfile(PatientProfileStatus profile) {
    _cachedProfileStatus = profile;
    if (profile.primaryCaregiver?.phone != null && profile.primaryCaregiver!.phone!.isNotEmpty) {
      _caregiverPhone = profile.primaryCaregiver!.phone;
    }
    if (profile.primaryCaregiver?.name.isNotEmpty ?? false) {
      _caregiverName = profile.primaryCaregiver!.name;
    }
    _caregivers = profile.caregivers;
    notifyListeners();
  }

  /// Checks the local SQLite database for a stored pairing code and automatically logs in.
  Future<bool> tryAutoLogin() async {
    _isInitializing = true;
    notifyListeners();

    try {
      // Pre-load cached profile status from local SQLite database in case offline
      final cachedProfile = await ActivityDatabaseService.instance.getProfileStatus();
      if (cachedProfile != null) {
        _cachedProfileStatus = cachedProfile;
        if (cachedProfile.primaryCaregiver?.phone != null) {
          _caregiverPhone = cachedProfile.primaryCaregiver!.phone;
        }
        if (cachedProfile.primaryCaregiver?.name.isNotEmpty ?? false) {
          _caregiverName = cachedProfile.primaryCaregiver!.name;
        }
        _caregivers = cachedProfile.caregivers;
      }

      // Pre-load guardian contact from local SQLite database in case offline
      final savedContact = await ActivityDatabaseService.instance.getGuardianContact();
      if (savedContact != null) {
        _guardianPhone = savedContact['phone'];
        _guardianName = savedContact['name'];
        _guardianRelationship = savedContact['relationship'];
        if (_caregiverPhone == null && _guardianPhone != null) {
          _caregiverPhone = _guardianPhone;
          _caregiverName = _guardianName ?? 'Caregiver';
        }
        if (_caregivers.isEmpty && _guardianPhone != null) {
          _caregivers = [
            CaregiverContact(
              name: _guardianName ?? 'Caregiver',
              phone: _guardianPhone,
              isPrimary: true,
            ),
          ];
        }
      }

      // Pre-load stored patient ID from local SQLite database in case offline
      final savedPatientId = await ActivityDatabaseService.instance.getActivePatientId();
      if (savedPatientId != null && savedPatientId.isNotEmpty) {
        _patientId = savedPatientId;
        _patientCode = savedPatientId;
      }

      // Pre-load cached diagnosis from SQLite
      final cachedDiag = await ActivityDatabaseService.instance.getPatientDiagnosis();
      if (cachedDiag != null) {
        _diagnosisInfo = cachedDiag;
      }

      final savedCode = await ActivityDatabaseService.instance.getActivePairingCode();
      if (savedCode != null && savedCode.trim().isNotEmpty) {
        debugPrint('[SessionService] Found stored pairing code $savedCode (Patient ID: $_patientId) in SQLite. Performing auto-login...');
        final success = await pairDevice(savedCode.trim());
        return success;
      }
    } catch (e) {
      debugPrint('[SessionService] Auto-login error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
    return false;
  }

  /// Authenticate and register device with pairing code through ApiService.
  /// Persists the pairing code, primary guardian phone number, and diagnosis in SQLite on success.
  Future<bool> pairDevice(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      _errorMessage = 'Please enter a valid pairing code.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;

    try {
      final session = await ApiService.instance.pairPatientWithCode(cleanCode);
      _isPaired = true;
      _pairingCode = cleanCode;
      _currentSession = session;
      _patientId = session.patientId;
      _patientCode = session.patientCode;
      _patientName = session.patientName;
      _caregiverId = session.caregiverId;
      _authToken = session.token;
      _regionLanguage = session.regionLanguage;
      _emergencyContact = session.emergencyContact;
      _guardianPhone = session.guardianPhone;
      _guardianName = session.guardianName;
      _guardianRelationship = session.guardianRelationship;
      _errorMessage = null;

      _caregiverPhone = session.caregiverPhone ?? session.guardianPhone;
      _caregiverName = session.caregiverName ?? session.guardianName ?? 'Caregiver';
      _caregivers = session.caregivers.map((c) => CaregiverContact.fromJson(c)).toList();
      if (_caregivers.isEmpty) {
        if (_caregiverPhone != null) {
          _caregivers = [
            CaregiverContact(
              name: _caregiverName!,
              phone: _caregiverPhone,
              isPrimary: true,
            ),
          ];
        }
      }

      final initialProfile = PatientProfileStatus(
        patientName: session.patientName,
        caregivers: _caregivers,
        emergencyContacts: session.emergencyContact != null && session.emergencyContact!['phone'] != null
            ? [
                ProfileEmergencyContact(
                  type: 'primary',
                  name: session.guardianName ?? session.emergencyContact!['name']?.toString() ?? '',
                  relationship: session.guardianRelationship ?? session.emergencyContact!['relationship']?.toString() ?? 'Primary Contact',
                  phone: session.guardianPhone ?? session.emergencyContact!['phone']?.toString() ?? '',
                ),
              ]
            : [],
        lastUpdated: DateTime.now(),
      );
      _cachedProfileStatus = initialProfile;
      await ActivityDatabaseService.instance.saveProfileStatus(initialProfile);

      // Save pairing code and guardian contact in local SQLite database for offline access & auto-login
      await ActivityDatabaseService.instance.savePairingCode(
        cleanCode,
        patientId: session.patientId,
        guardianPhone: session.guardianPhone,
        guardianName: session.guardianName,
        guardianRelationship: session.guardianRelationship,
      );

      // Load or persist diagnosis
      if (session.diagnosis != null && session.diagnosis!.isNotEmpty) {
        final diagInfo = PatientDiagnosisInfo(
          pairingCode: cleanCode,
          patientId: session.patientId,
          patientName: session.patientName,
          rawDiagnosis: session.diagnosis!,
          priority: DiagnosisPriority.fromString(session.diagnosis),
          fetchedAt: DateTime.now(),
        );
        _diagnosisInfo = diagInfo;
        await ActivityDatabaseService.instance.savePatientDiagnosis(diagInfo);
      } else {
        _diagnosisInfo = await ActivityDatabaseService.instance.getPatientDiagnosis(pairingCode: cleanCode);
      }

      // Proactively refresh latest diagnosis from backend MongoDB in background
      refreshDiagnosis();

      notifyListeners();
      return true;
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      _errorMessage = cleanError.isNotEmpty ? cleanError : 'Unable to connect with this code.';
      notifyListeners();
      return false;
    }
  }

  /// Fetches latest diagnosis from backend MongoDB identified with active pairing code
  /// and persists it to local SQLite table.
  Future<void> refreshDiagnosis() async {
    final code = _pairingCode ?? await ActivityDatabaseService.instance.getActivePairingCode();
    if (code == null || code.isEmpty) return;

    try {
      final fetched = await ApiService.instance.fetchPatientDiagnosis(code);
      _diagnosisInfo = fetched;
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionService] Background diagnosis refresh skipped: $e');
    }
  }

  /// Reset session state, clear stored pairing code, diagnosis, and guardian contact from SQLite, and unpair device.
  Future<void> unpair() async {
    _isPaired = false;
    _pairingCode = null;
    _currentSession = null;
    _diagnosisInfo = null;
    _authToken = null;
    _caregiverId = null;
    _emergencyContact = null;
    _guardianPhone = null;
    _guardianName = null;
    _guardianRelationship = null;
    _caregiverPhone = null;
    _caregiverName = null;
    _caregivers = [];
    _cachedProfileStatus = null;
    _errorMessage = null;

    // Clear pairing code, diagnosis, and guardian contact from SQLite so app does not auto-login again until paired
    await ActivityDatabaseService.instance.clearSavedPairingCode();
    await ActivityDatabaseService.instance.clearPatientDiagnosis();

    notifyListeners();
  }

  @visibleForTesting
  void setPairedForTesting(
    String code, {
    String? patientId,
    String? patientName,
    String? guardianPhone,
    String? guardianName,
    String? guardianRelationship,
    String? caregiverPhone,
    String? caregiverName,
    List<CaregiverContact>? caregivers,
    PatientProfileStatus? profileStatus,
  }) {
    _isPaired = true;
    _pairingCode = code;
    if (patientId != null) {
      _patientId = patientId;
      _patientCode = patientId;
    }
    if (patientName != null) {
      _patientName = patientName;
    }
    _guardianPhone = guardianPhone;
    _guardianName = guardianName;
    _guardianRelationship = guardianRelationship;
    _caregiverPhone = caregiverPhone;
    _caregiverName = caregiverName;
    if (caregivers != null) {
      _caregivers = caregivers;
    }
    if (profileStatus != null) {
      _cachedProfileStatus = profileStatus;
    } else if (caregiverPhone != null || caregiverName != null || caregivers != null) {
      _cachedProfileStatus = PatientProfileStatus(
        patientName: _patientName,
        caregivers: caregivers ?? [
          if (caregiverName != null || caregiverPhone != null)
            CaregiverContact(
              name: caregiverName ?? 'Caregiver',
              phone: caregiverPhone,
              isPrimary: true,
            ),
        ],
        emergencyContacts: [
          if (guardianPhone != null || guardianName != null)
            ProfileEmergencyContact(
              type: 'primary',
              name: guardianName ?? 'Emergency Contact',
              relationship: guardianRelationship ?? 'Emergency Contact',
              phone: guardianPhone ?? '',
            ),
        ],
        lastUpdated: DateTime.now(),
      );
    }
    notifyListeners();
  }
}



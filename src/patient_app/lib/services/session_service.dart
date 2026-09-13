import 'package:flutter/foundation.dart';
import '../models/patient_diagnosis.dart';
import '../models/patient_session.dart';
import 'activity_database_service.dart';
import 'api_service.dart';

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
  PatientSession? get currentSession => _currentSession;
  PatientDiagnosisInfo? get diagnosisInfo => _diagnosisInfo;
  String? get diagnosis => _diagnosisInfo?.rawDiagnosis ?? _currentSession?.diagnosis;
  int get diagnosisPriorityNumber => _diagnosisInfo?.priorityNumber ?? 7;
  String? get errorMessage => _errorMessage;

  /// Checks the local SQLite database for a stored pairing code and automatically logs in.
  Future<bool> tryAutoLogin() async {
    _isInitializing = true;
    notifyListeners();

    try {
      // Pre-load guardian contact from local SQLite database in case offline
      final savedContact = await ActivityDatabaseService.instance.getGuardianContact();
      if (savedContact != null) {
        _guardianPhone = savedContact['phone'];
        _guardianName = savedContact['name'];
        _guardianRelationship = savedContact['relationship'];
      }

      // Pre-load cached diagnosis from SQLite
      final cachedDiag = await ActivityDatabaseService.instance.getPatientDiagnosis();
      if (cachedDiag != null) {
        _diagnosisInfo = cachedDiag;
      }

      final savedCode = await ActivityDatabaseService.instance.getActivePairingCode();
      if (savedCode != null && savedCode.trim().isNotEmpty) {
        debugPrint('[SessionService] Found stored pairing code $savedCode in SQLite. Performing auto-login...');
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
    _errorMessage = null;

    // Clear pairing code, diagnosis, and guardian contact from SQLite so app does not auto-login again until paired
    await ActivityDatabaseService.instance.clearSavedPairingCode();
    await ActivityDatabaseService.instance.clearPatientDiagnosis();

    notifyListeners();
  }
}



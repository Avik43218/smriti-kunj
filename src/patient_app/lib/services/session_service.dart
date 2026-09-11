import 'package:flutter/foundation.dart';
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
  PatientSession? _currentSession;
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
  PatientSession? get currentSession => _currentSession;
  String? get errorMessage => _errorMessage;

  /// Checks the local SQLite database for a stored pairing code and automatically logs in.
  Future<bool> tryAutoLogin() async {
    _isInitializing = true;
    notifyListeners();

    try {
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
  /// Persists the pairing code in the local SQLite database on success.
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
      _errorMessage = null;

      // Save pairing code in local SQLite database for auto-login on next app launch
      await ActivityDatabaseService.instance.savePairingCode(
        cleanCode,
        patientId: session.patientId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      _errorMessage = cleanError.isNotEmpty ? cleanError : 'Unable to connect with this code.';
      notifyListeners();
      return false;
    }
  }

  /// Reset session state, clear stored pairing code from SQLite, and unpair device.
  Future<void> unpair() async {
    _isPaired = false;
    _pairingCode = null;
    _currentSession = null;
    _authToken = null;
    _caregiverId = null;
    _emergencyContact = null;
    _errorMessage = null;

    // Clear pairing code from SQLite so app does not auto-login again until paired
    await ActivityDatabaseService.instance.clearSavedPairingCode();

    notifyListeners();
  }
}

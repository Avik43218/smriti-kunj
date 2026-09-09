import 'package:flutter/foundation.dart';
import '../models/patient_session.dart';
import 'api_service.dart';

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();

  SessionService._internal();
  factory SessionService() => instance;

  bool _isPaired = false;
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

  /// Authenticate and register device with pairing code through ApiService.
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

      notifyListeners();
      return true;
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      _errorMessage = cleanError.isNotEmpty ? cleanError : 'Unable to connect with this code.';
      notifyListeners();
      return false;
    }
  }

  /// Reset session state and unpair device.
  void unpair() {
    _isPaired = false;
    _pairingCode = null;
    _currentSession = null;
    _authToken = null;
    _caregiverId = null;
    _emergencyContact = null;
    _errorMessage = null;
    notifyListeners();
  }
}

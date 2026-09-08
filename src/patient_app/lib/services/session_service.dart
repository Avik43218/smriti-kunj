import 'package:flutter/foundation.dart';

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();

  SessionService._internal();
  factory SessionService() => instance;

  bool _isPaired = false;
  String? _pairingCode;
  final String _patientId = 'p101';
  final String _patientName = 'Aarav Sharma';

  bool get isPaired => _isPaired;
  String? get pairingCode => _pairingCode;
  String get patientId => _patientId;
  String get patientName => _patientName;

  /// Saves mocked paired state and notifies listeners.
  Future<bool> pairDevice(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      return false;
    }

    // Simulate short network delay for realism
    await Future.delayed(const Duration(milliseconds: 300));

    _isPaired = true;
    _pairingCode = cleanCode;
    notifyListeners();
    return true;
  }

  void unpair() {
    _isPaired = false;
    _pairingCode = null;
    notifyListeners();
  }
}

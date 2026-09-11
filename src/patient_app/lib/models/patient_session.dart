class PatientSession {
  final String patientId;
  final String patientCode;
  final String patientName;
  final String? caregiverId;
  final String token;
  final String regionLanguage;
  final Map<String, dynamic>? emergencyContact;
  final String? diagnosis;
  final String status;

  const PatientSession({
    required this.patientId,
    required this.patientCode,
    required this.patientName,
    this.caregiverId,
    required this.token,
    this.regionLanguage = 'bn',
    this.emergencyContact,
    this.diagnosis,
    this.status = 'stable',
  });

  factory PatientSession.fromJson(Map<String, dynamic> json) {
    final tokenData = json['token'];
    String accessToken = '';
    if (tokenData is Map<String, dynamic>) {
      accessToken = (tokenData['access_token'] as String?) ?? '';
    } else if (tokenData is String) {
      accessToken = tokenData;
    }

    return PatientSession(
      patientId: json['patient_id']?.toString() ?? json['id']?.toString() ?? '',
      patientCode: json['patient_code']?.toString() ?? json['patientCode']?.toString() ?? 'p101',
      patientName: json['patient_name']?.toString() ?? json['name']?.toString() ?? 'Patient',
      caregiverId: json['caregiver_id']?.toString(),
      token: accessToken,
      regionLanguage: json['region_language']?.toString() ?? 'bn',
      emergencyContact: json['emergency_contact'] as Map<String, dynamic>?,
      diagnosis: json['diagnosis']?.toString(),
      status: json['status']?.toString() ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'patient_code': patientCode,
    'patient_name': patientName,
    'caregiver_id': caregiverId,
    'token': token,
    'region_language': regionLanguage,
    'emergency_contact': emergencyContact,
    'diagnosis': diagnosis,
    'status': status,
  };
}

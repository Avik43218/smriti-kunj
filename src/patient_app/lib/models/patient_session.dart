class PatientSession {
  final String patientId;
  final String patientCode;
  final String patientName;
  final String? caregiverId;
  final String token;
  final String regionLanguage;
  final Map<String, dynamic>? emergencyContact;
  final String? guardianPhone;
  final String? guardianName;
  final String? guardianRelationship;
  final String? caregiverPhone;
  final String? caregiverName;
  final List<Map<String, dynamic>> caregivers;
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
    this.guardianPhone,
    this.guardianName,
    this.guardianRelationship,
    this.caregiverPhone,
    this.caregiverName,
    this.caregivers = const [],
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

    final rawEmergency = json['emergency_contact'] is Map
        ? json['emergency_contact'] as Map<String, dynamic>
        : (json['emergencyContact'] is Map
            ? json['emergencyContact'] as Map<String, dynamic>
            : null);

    final gPhone = json['guardian_phone']?.toString() ??
        json['guardianPhone']?.toString() ??
        rawEmergency?['phone']?.toString();

    final gName = json['guardian_name']?.toString() ??
        json['guardianName']?.toString() ??
        rawEmergency?['name']?.toString();

    final gRel = json['guardian_relationship']?.toString() ??
        json['guardianRelationship']?.toString() ??
        rawEmergency?['relationship']?.toString();

    final cgPhone = json['caregiver_phone']?.toString() ??
        json['caregiverPhone']?.toString();

    final cgName = json['caregiver_name']?.toString() ??
        json['caregiverName']?.toString();

    final List<Map<String, dynamic>> cgs = [];
    if (json['caregivers'] is List) {
      for (final item in json['caregivers'] as List) {
        if (item is Map<String, dynamic>) {
          cgs.add(item);
        } else if (item is Map) {
          cgs.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final pCode = json['patient_code']?.toString() ?? json['patientCode']?.toString() ?? 'p101';
    final rawPId = json['patient_id']?.toString() ?? json['id']?.toString();
    final resolvedId = (rawPId != null && rawPId.trim().isNotEmpty)
        ? rawPId.trim()
        : pCode;

    return PatientSession(
      patientId: resolvedId,
      patientCode: pCode,
      patientName: json['patient_name']?.toString() ?? json['name']?.toString() ?? 'Patient',
      caregiverId: json['caregiver_id']?.toString() ?? json['caregiverId']?.toString(),
      token: accessToken,
      regionLanguage: json['region_language']?.toString() ?? json['preferredLanguage']?.toString() ?? 'bn',
      emergencyContact: rawEmergency,
      guardianPhone: gPhone,
      guardianName: gName,
      guardianRelationship: gRel,
      caregiverPhone: cgPhone,
      caregiverName: cgName,
      caregivers: cgs,
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
    'guardian_phone': guardianPhone,
    'guardian_name': guardianName,
    'guardian_relationship': guardianRelationship,
    'caregiver_phone': caregiverPhone,
    'caregiver_name': caregiverName,
    'caregivers': caregivers,
    'diagnosis': diagnosis,
    'status': status,
  };
}


import 'dart:convert';

/// Represents a single emergency contact (primary or alternative).
class ProfileEmergencyContact {
  final String type; // 'primary' or 'alternative'
  final String name;
  final String relationship;
  final String phone;

  const ProfileEmergencyContact({
    required this.type,
    required this.name,
    required this.relationship,
    required this.phone,
  });

  bool get isPrimary => type.toLowerCase() == 'primary';
  bool get isAlternative => type.toLowerCase() == 'alternative';

  /// Normalizes the phone number: preserves leading '+', strips non-digits.
  String get normalizedDialNumber {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    return phone.trim().startsWith('+') ? '+$clean' : clean;
  }

  /// Formats phone number for clear visual display with grouping (e.g. `+91 98765 43210`).
  String get formattedDisplayNumber {
    final clean = normalizedDialNumber;
    if (clean.startsWith('+91') && clean.length == 13) {
      // +91 XXXXX XXXXX
      return '+91 ${clean.substring(3, 8)} ${clean.substring(8)}';
    } else if (clean.length == 10 && !clean.startsWith('+')) {
      // XXXXX XXXXX
      return '${clean.substring(0, 5)} ${clean.substring(5)}';
    } else if (clean.length > 7) {
      // Generic chunking
      final hasPlus = clean.startsWith('+');
      final digits = hasPlus ? clean.substring(1) : clean;
      final mid = digits.length ~/ 2;
      return '${hasPlus ? '+' : ''}${digits.substring(0, mid)} ${digits.substring(mid)}';
    }
    return clean;
  }

  /// Digit-by-digit spaced string for screen readers.
  String get screenReaderSpokenDigits {
    return normalizedDialNumber.split('').join(' ');
  }

  factory ProfileEmergencyContact.fromJson(Map<String, dynamic> json) {
    return ProfileEmergencyContact(
      type: json['type']?.toString() ?? 'primary',
      name: json['name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'relationship': relationship,
    'phone': phone,
  };
}

/// Represents a caregiver contact.
class CaregiverContact {
  final String name;
  final String? phone;
  final bool isPrimary;

  const CaregiverContact({
    required this.name,
    this.phone,
    this.isPrimary = false,
  });

  /// Normalizes the phone number: preserves leading '+', strips non-digits.
  String? get normalizedDialNumber {
    if (phone == null || phone!.trim().isEmpty) return null;
    final clean = phone!.replaceAll(RegExp(r'[^\d]'), '');
    return phone!.trim().startsWith('+') ? '+$clean' : clean;
  }

  /// Formats phone number for clear visual display with grouping.
  String? get formattedDisplayNumber {
    final clean = normalizedDialNumber;
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

  factory CaregiverContact.fromJson(Map<String, dynamic> json) {
    return CaregiverContact(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      isPrimary: json['is_primary'] == true || json['isPrimary'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (phone != null) 'phone': phone,
    'is_primary': isPrimary,
  };
}

/// Read-only profile status data for the patient app.
class PatientProfileStatus {
  final String patientName;
  final List<CaregiverContact> caregivers;
  final List<String> caregiverNames;
  final List<ProfileEmergencyContact> emergencyContacts;
  final DateTime? lastUpdated;

  PatientProfileStatus({
    required this.patientName,
    List<CaregiverContact>? caregivers,
    List<String>? caregiverNames,
    this.emergencyContacts = const [],
    this.lastUpdated,
  })  : caregivers = caregivers ??
            (caregiverNames ?? const [])
                .map((n) => CaregiverContact(name: n))
                .toList(),
        caregiverNames = caregiverNames ??
            (caregivers ?? const [])
                .map((c) => c.name)
                .where((n) => n.trim().isNotEmpty)
                .toList();

  bool get isEmpty =>
      patientName.trim().isEmpty &&
      caregivers.isEmpty &&
      emergencyContacts.isEmpty;

  String get caregiverDisplayName => caregiverNames.join(', ');

  List<ProfileEmergencyContact> get contacts => emergencyContacts;

  CaregiverContact? get primaryCaregiver {
    try {
      return caregivers.firstWhere((c) => c.isPrimary);
    } catch (_) {
      return caregivers.isNotEmpty ? caregivers.first : null;
    }
  }

  ProfileEmergencyContact? get primaryContact {
    try {
      return emergencyContacts.firstWhere((c) => c.isPrimary);
    } catch (_) {
      return emergencyContacts.isNotEmpty ? emergencyContacts.first : null;
    }
  }

  ProfileEmergencyContact? get alternativeContact {
    try {
      return emergencyContacts.firstWhere((c) => c.isAlternative);
    } catch (_) {
      return emergencyContacts.length > 1 ? emergencyContacts[1] : null;
    }
  }

  factory PatientProfileStatus.fromJson(Map<String, dynamic> json) {
    final patientName = json['patient_name']?.toString() ??
        json['patientName']?.toString() ??
        json['name']?.toString() ??
        '';

    final List<CaregiverContact> cList = [];
    if (json['caregivers'] is List) {
      for (final item in json['caregivers'] as List) {
        if (item is Map<String, dynamic>) {
          cList.add(CaregiverContact.fromJson(item));
        } else if (item is Map) {
          cList.add(CaregiverContact.fromJson(Map<String, dynamic>.from(item)));
        } else if (item is String && item.trim().isNotEmpty) {
          cList.add(CaregiverContact(name: item.trim()));
        }
      }
    } else if (json['caregiver_name'] != null) {
      final n = json['caregiver_name'].toString().trim();
      if (n.isNotEmpty) {
        cList.add(CaregiverContact(
          name: n,
          phone: json['caregiver_phone']?.toString(),
          isPrimary: true,
        ));
      }
    }

    final List<ProfileEmergencyContact> contacts = [];
    if (json['emergency_contacts'] is List) {
      for (final item in json['emergency_contacts'] as List) {
        if (item is Map<String, dynamic>) {
          contacts.add(ProfileEmergencyContact.fromJson(item));
        } else if (item is Map) {
          contacts.add(ProfileEmergencyContact.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } else {
      // Fallback from legacy emergency_contact and alternative_emergency_contact
      if (json['emergency_contact'] is Map) {
        final ec = Map<String, dynamic>.from(json['emergency_contact'] as Map);
        if ((ec['name']?.toString().trim().isNotEmpty ?? false) ||
            (ec['phone']?.toString().trim().isNotEmpty ?? false)) {
          contacts.add(ProfileEmergencyContact(
            type: 'primary',
            name: ec['name']?.toString() ?? '',
            relationship: ec['relationship']?.toString() ?? 'Primary Contact',
            phone: ec['phone']?.toString() ?? '',
          ));
        }
      } else if (json['guardian_phone'] != null) {
        contacts.add(ProfileEmergencyContact(
          type: 'primary',
          name: json['guardian_name']?.toString() ?? '',
          relationship: json['guardian_relationship']?.toString() ?? 'Primary Contact',
          phone: json['guardian_phone']?.toString() ?? '',
        ));
      }

      if (json['alternative_emergency_contact'] is Map) {
        final aec = Map<String, dynamic>.from(json['alternative_emergency_contact'] as Map);
        if ((aec['name']?.toString().trim().isNotEmpty ?? false) ||
            (aec['phone']?.toString().trim().isNotEmpty ?? false)) {
          contacts.add(ProfileEmergencyContact(
            type: 'alternative',
            name: aec['name']?.toString() ?? '',
            relationship: aec['relationship']?.toString() ?? 'Alternative Contact',
            phone: aec['phone']?.toString() ?? '',
          ));
        }
      }
    }

    DateTime? updated;
    final rawUpdated = json['last_updated']?.toString() ?? json['lastUpdated']?.toString();
    if (rawUpdated != null && rawUpdated.trim().isNotEmpty) {
      updated = DateTime.tryParse(rawUpdated);
    }

    if (cList.isEmpty && contacts.isNotEmpty) {
      final primary = contacts.firstWhere((c) => c.isPrimary, orElse: () => contacts.first);
      cList.add(CaregiverContact(
        name: primary.name.isNotEmpty ? primary.name : 'Caregiver',
        phone: primary.phone.isNotEmpty ? primary.phone : null,
        isPrimary: true,
      ));
    }

    return PatientProfileStatus(
      patientName: patientName,
      caregivers: cList,
      emergencyContacts: contacts,
      lastUpdated: updated,
    );
  }

  Map<String, dynamic> toJson() => {
    'patient_name': patientName,
    'caregivers': caregivers.map((c) => c.toJson()).toList(),
    'emergency_contacts': emergencyContacts.map((c) => c.toJson()).toList(),
    'last_updated': lastUpdated?.toIso8601String(),
  };

  Map<String, dynamic> toMap() => {
    'patient_name': patientName,
    'caregivers_json': jsonEncode(caregivers.map((c) => c.toJson()).toList()),
    'contacts_json': jsonEncode(emergencyContacts.map((c) => c.toJson()).toList()),
    'last_updated': lastUpdated?.toIso8601String(),
  };

  factory PatientProfileStatus.fromMap(Map<String, dynamic> map) {
    final patientName = map['patient_name']?.toString() ?? '';
    final List<CaregiverContact> cList = [];
    if (map['caregivers_json'] != null) {
      try {
        final decoded = jsonDecode(map['caregivers_json'].toString());
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              cList.add(CaregiverContact.fromJson(item));
            } else if (item is Map) {
              cList.add(CaregiverContact.fromJson(Map<String, dynamic>.from(item)));
            } else if (item != null) {
              cList.add(CaregiverContact(name: item.toString()));
            }
          }
        }
      } catch (_) {}
    }

    final List<ProfileEmergencyContact> contacts = [];
    if (map['contacts_json'] != null) {
      try {
        final decoded = jsonDecode(map['contacts_json'].toString());
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              contacts.add(ProfileEmergencyContact.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (_) {}
    }

    if (cList.isEmpty && contacts.isNotEmpty) {
      final primary = contacts.firstWhere((c) => c.isPrimary, orElse: () => contacts.first);
      cList.add(CaregiverContact(
        name: primary.name.isNotEmpty ? primary.name : 'Caregiver',
        phone: primary.phone.isNotEmpty ? primary.phone : null,
        isPrimary: true,
      ));
    }

    DateTime? updated;
    if (map['last_updated'] != null) {
      updated = DateTime.tryParse(map['last_updated'].toString());
    }

    return PatientProfileStatus(
      patientName: patientName,
      caregivers: cList,
      emergencyContacts: contacts,
      lastUpdated: updated,
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum MemoryType {
  photo,
  audio;

  static MemoryType fromString(String? val) {
    if (val != null && val.toLowerCase() == 'audio') {
      return MemoryType.audio;
    }
    return MemoryType.photo;
  }
}

class MemoryItem {
  final String id;
  final String patientId;
  final String title;
  final String subtitle;
  final String relationship;
  final MemoryType type;
  final String? photoUrl;
  final String? audioUrl;
  final String? audioDuration;
  final IconData placeholderIcon;
  final Color accentColor;
  final DateTime? createdAt;

  const MemoryItem({
    required this.id,
    this.patientId = 'p101',
    required this.title,
    required this.subtitle,
    required this.relationship,
    required this.type,
    this.photoUrl,
    this.audioUrl,
    this.audioDuration,
    required this.placeholderIcon,
    required this.accentColor,
    this.createdAt,
  });

  bool get isAudio => type == MemoryType.audio;
  bool get isPhoto => type == MemoryType.photo;

  static IconData defaultIconFor(MemoryType type, String relationship) {
    if (type == MemoryType.audio) {
      return Icons.volume_up_rounded;
    }
    final rel = relationship.toLowerCase();
    if (rel.contains('daughter') || rel.contains('mother') || rel.contains('sister') || rel.contains('granddaughter')) {
      return Icons.face_3_rounded;
    }
    if (rel.contains('son') || rel.contains('father') || rel.contains('brother') || rel.contains('grandson')) {
      return Icons.face_rounded;
    }
    return Icons.photo_camera_rounded;
  }

  static Color defaultAccentFor(MemoryType type, int index) {
    if (type == MemoryType.audio) {
      return AppColors.terracotta;
    }
    const colors = [
      AppColors.terracotta,
      AppColors.sageGreen,
      Color(0xFFD97706), // warm amber
      Color(0xFF2563EB), // calm blue
      Color(0xFF7C3AED), // gentle purple
    ];
    return colors[index % colors.length];
  }

  factory MemoryItem.fromJson(Map<String, dynamic> json, {String? defaultPatientId, int index = 0}) {
    final rawType = json['type']?.toString().toLowerCase();
    final type = (rawType == 'audio' || (json['audioUrl'] != null && json['photoUrl'] == null))
        ? MemoryType.audio
        : MemoryType.photo;

    final id = json['id']?.toString() ?? 'mem_${DateTime.now().millisecondsSinceEpoch}';
    final patientId = json['patientId']?.toString() ?? json['patient_id']?.toString() ?? defaultPatientId ?? 'p101';
    final title = json['title']?.toString() ?? json['name']?.toString() ?? json['caption']?.toString() ?? 'Family Memory';
    final relationship = json['relationship']?.toString() ?? json['relation']?.toString() ?? (type == MemoryType.audio ? 'Family Voice' : 'Family Member');
    final subtitle = json['subtitle']?.toString() ?? (type == MemoryType.audio ? 'Voice Note & Sound' : '$relationship • Family Photograph');
    final photoUrl = json['photoUrl']?.toString() ?? json['photo_url']?.toString();
    final audioUrl = json['audioUrl']?.toString() ?? json['audio_url']?.toString();
    final duration = json['audioDuration']?.toString() ?? json['duration']?.toString();

    DateTime? parsedCreated;
    final rawCreated = json['createdAt']?.toString() ?? json['created_at']?.toString();
    if (rawCreated != null && rawCreated.isNotEmpty) {
      parsedCreated = DateTime.tryParse(rawCreated);
    }

    return MemoryItem(
      id: id,
      patientId: patientId,
      title: title,
      subtitle: subtitle,
      relationship: relationship,
      type: type,
      photoUrl: photoUrl,
      audioUrl: audioUrl,
      audioDuration: duration,
      placeholderIcon: defaultIconFor(type, relationship),
      accentColor: defaultAccentFor(type, index),
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'title': title,
      'subtitle': subtitle,
      'relationship': relationship,
      'type': type.name,
      'photo_url': photoUrl,
      'audio_url': audioUrl,
      'duration': audioDuration,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory MemoryItem.fromMap(Map<String, dynamic> map, {int index = 0}) {
    final type = MemoryType.fromString(map['type']?.toString());
    final relationship = map['relationship']?.toString() ?? (type == MemoryType.audio ? 'Family Voice' : 'Family Member');

    DateTime? parsedCreated;
    final rawCreated = map['created_at']?.toString();
    if (rawCreated != null && rawCreated.isNotEmpty) {
      parsedCreated = DateTime.tryParse(rawCreated);
    }

    return MemoryItem(
      id: map['id']?.toString() ?? 'mem_${DateTime.now().millisecondsSinceEpoch}',
      patientId: map['patient_id']?.toString() ?? 'p101',
      title: map['title']?.toString() ?? 'Family Memory',
      subtitle: map['subtitle']?.toString() ?? (type == MemoryType.audio ? 'Voice Note & Sound' : '$relationship • Family Photograph'),
      relationship: relationship,
      type: type,
      photoUrl: map['photo_url']?.toString(),
      audioUrl: map['audio_url']?.toString(),
      audioDuration: map['duration']?.toString(),
      placeholderIcon: defaultIconFor(type, relationship),
      accentColor: defaultAccentFor(type, index),
      createdAt: parsedCreated,
    );
  }
}

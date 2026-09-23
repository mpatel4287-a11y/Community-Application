// lib/models/attendance_model.dart

class AttendanceModel {
  final String id;
  final String eventId;
  final String markedBy; // Member ID who marked attendance
  final String markedByName; // Name of person who marked
  final String attendanceType; // 'whole_family' | 'sub_family'
  final String entityId; // familyDocId | subFamilyDocId
  final String entityName; // Display name (e.g., family name or sub-family name)
  final String familyDocId; // Main family document ID
  final String subFamilyDocId; // Sub-family document ID (if sub-family)
  final List<String> memberIds; // List of member IDs included in this attendance
  final int memberCount; // Total count (1 to 30)
  final DateTime markedAt;
  final bool isCustomCount;

  AttendanceModel({
    required this.id,
    required this.eventId,
    required this.markedBy,
    required this.markedByName,
    required this.attendanceType,
    required this.entityId,
    required this.entityName,
    this.familyDocId = '',
    this.subFamilyDocId = '',
    required this.memberIds,
    required this.memberCount,
    required this.markedAt,
    this.isCustomCount = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'markedBy': markedBy,
      'markedByName': markedByName,
      'attendanceType': attendanceType,
      'entityId': entityId,
      'entityName': entityName,
      'familyDocId': familyDocId,
      'subFamilyDocId': subFamilyDocId,
      'memberIds': memberIds,
      'memberCount': memberCount,
      'markedAt': markedAt,
      'isCustomCount': isCustomCount,
    };
  }

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> data) {
    String type = data['attendanceType'] ?? 'whole_family';
    if (type == 'family') type = 'whole_family';
    if (type == 'subfamily') type = 'sub_family';

    final entityId = data['entityId'] ?? '';
    final rawFamilyDocId = (data['familyDocId'] as String?)?.trim() ?? '';
    final rawSubFamilyDocId = (data['subFamilyDocId'] as String?)?.trim() ?? '';

    return AttendanceModel(
      id: id,
      eventId: data['eventId'] ?? '',
      markedBy: data['markedBy'] ?? '',
      markedByName: data['markedByName'] ?? '',
      attendanceType: type,
      entityId: entityId,
      entityName: data['entityName'] ?? '',
      familyDocId: rawFamilyDocId.isNotEmpty ? rawFamilyDocId : (type == 'whole_family' ? entityId : ''),
      subFamilyDocId: rawSubFamilyDocId.isNotEmpty ? rawSubFamilyDocId : (type == 'sub_family' ? entityId : ''),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberCount: data['memberCount'] ?? 0,
      markedAt: data['markedAt'] is DateTime
          ? data['markedAt']
          : ((data['markedAt'] as dynamic)?.toDate() ?? DateTime.now()),
      isCustomCount: data['isCustomCount'] ?? false,
    );
  }
}


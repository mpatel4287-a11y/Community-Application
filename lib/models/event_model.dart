// lib/models/event_model.dart

class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String time;
  final String type;
  final String createdBy;
  final String familyDocId;
  final DateTime createdAt;
  
  // Visibility settings
  final String visibilityType; // 'all' | 'selected' | 'group'
  final List<String> visibleToMemberIds; // Member IDs who can see this event
  final List<String> visibleToGroupIds; // Group IDs who can see this event

  // Attendance Settings
  final int attendanceTimeLimit; // Minutes to allow editing/deleting attendance

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    this.location = '',
    required this.date,
    this.time = '',
    this.type = 'general',
    required this.createdBy,
    this.familyDocId = '',
    required this.createdAt,
    this.visibilityType = 'all',
    this.visibleToMemberIds = const [],
    this.visibleToGroupIds = const [],
    this.attendanceTimeLimit = 60,
  });

  // ---------------- TO MAP ----------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'time': time,
      'type': type,
      'createdBy': createdBy,
      'familyDocId': familyDocId,
      'createdAt': createdAt,
      'visibilityType': visibilityType,
      'visibleToMemberIds': visibleToMemberIds,
      'visibleToGroupIds': visibleToGroupIds,
      'attendanceTimeLimit': attendanceTimeLimit,
    };
  }

  // ---------------- FROM MAP ----------------
  factory EventModel.fromMap(String id, Map<String, dynamic> data) {
    return EventModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      date: (data['date'] as dynamic)?.toDate() ?? DateTime.now(),
      time: data['time'] ?? '',
      type: data['type'] ?? 'general',
      createdBy: data['createdBy'] ?? '',
      familyDocId: data['familyDocId'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      visibilityType: data['visibilityType'] ?? 'all',
      visibleToMemberIds: List<String>.from(data['visibleToMemberIds'] ?? []),
      visibleToGroupIds: List<String>.from(data['visibleToGroupIds'] ?? []),
      attendanceTimeLimit: data['attendanceTimeLimit'] ?? 60,
    );
  }
}

// lib/services/event_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import 'notification_service.dart';
import 'fcm_service.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------- CREATE EVENT ----------------
  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required String createdBy,
    String location = '',
    String type = 'general',
    String time = '',
    String familyDocId = '',
    String visibilityType = 'all',
    List<String> visibleToMemberIds = const [],
    List<String> visibleToGroupIds = const [],
    int attendanceTimeLimit = 60,
  }) async {
    final eventRef = _firestore.collection('events').doc();

    final event = EventModel(
      id: eventRef.id,
      title: title.trim(),
      description: description.trim(),
      location: location.trim(),
      date: date,
      time: time,
      type: type,
      createdBy: createdBy,
      familyDocId: familyDocId,
      createdAt: DateTime.now(),
      visibilityType: visibilityType,
      visibleToMemberIds: visibleToMemberIds,
      visibleToGroupIds: visibleToGroupIds,
      attendanceTimeLimit: attendanceTimeLimit,
    );

    await eventRef.set(event.toMap());

    // NEW: Auto-create notification for everyone
    await NotificationService().createNotification(
      title: 'New Event: ${event.title}',
      message: 'A new event has been scheduled for ${_formatDate(event.date)}',
      type: 'event',
      targetType: 'all',
      targetId: event.id,
      createdBy: createdBy,
    );

    // NEW: Trigger Push Notification for everyone
    await FcmService.sendPushToTopic(
      title: 'New Event: ${event.title}',
      body: 'A new event has been scheduled for ${_formatDate(event.date)}',
      topic: 'all',
    );
  }

  // ---------------- SEND REMINDER ----------------
  Future<void> sendEventReminder({
    required EventModel event,
    required String triggeredBy,
  }) async {
    await NotificationService().createNotification(
      title: 'Reminder: ${event.title}',
      message: 'Don\'t forget! ${event.title} is happening on ${_formatDate(event.date)} at ${_formatTime(event.date)}.',
      type: 'event',
      targetType: 'all',
      targetId: event.id,
      createdBy: triggeredBy,
    );

    // NEW: Trigger Push Notification for everyone
    await FcmService.sendPushToTopic(
      title: 'Reminder: ${event.title}',
      body: 'Don\'t forget! ${event.title} is happening on ${_formatDate(event.date)}',
      topic: 'all',
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formatTime(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  // ---------------- UPDATE EVENT ----------------
  Future<void> updateEvent({
    required String eventId,
    String? title,
    String? description,
    String? location,
    DateTime? date,
    String? time,
    String? type,
    String? visibilityType,
    List<String>? visibleToMemberIds,
    List<String>? visibleToGroupIds,
    int? attendanceTimeLimit,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (location != null) updates['location'] = location;
    if (date != null) updates['date'] = date;
    if (time != null) updates['time'] = time;
    if (type != null) updates['type'] = type;
    if (visibilityType != null) updates['visibilityType'] = visibilityType;
    if (visibleToMemberIds != null) updates['visibleToMemberIds'] = visibleToMemberIds;
    if (visibleToMemberIds != null) updates['visibleToMemberIds'] = visibleToMemberIds;
    if (visibleToGroupIds != null) updates['visibleToGroupIds'] = visibleToGroupIds;
    if (attendanceTimeLimit != null) updates['attendanceTimeLimit'] = attendanceTimeLimit;

    if (updates.isNotEmpty) {
      await _firestore.collection('events').doc(eventId).update(updates);
    }
  }

  // ---------------- DELETE EVENT ----------------
  Future<void> deleteEvent(String eventId) async {
    // Delete all attendance records for this event
    final attendance = await _firestore
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .get();

    for (final doc in attendance.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('events').doc(eventId).delete();
  }

  // ---------------- STREAM EVENTS (ALL) ----------------
  Stream<List<EventModel>> streamAllEvents({
    String? currentMemberId, 
    List<String>? currentGroupIds,
    String? userRole,
  }) {
    return _firestore
        .collection('events')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) {
            final events = snap.docs
                .map((doc) => EventModel.fromMap(doc.id, doc.data()))
                .toList();
            
            // Filter by visibility
            // 1. Admins and Managers always see everything
            if (userRole == 'admin' || userRole == 'manager') {
              return events;
            }

            // 2. Otherwise, filter strictly
            if (currentMemberId != null || currentGroupIds != null) {
              return events.where((event) {
                if (event.visibilityType == 'all') return true;
                if (event.visibilityType == 'selected') {
                  // Check if member is explicitly selected (using Document ID)
                  if (currentMemberId != null && event.visibleToMemberIds.contains(currentMemberId)) {
                    return true;
                  }
                  // Check if member belongs to any selected group
                  if (currentGroupIds != null) {
                    return event.visibleToGroupIds.any((gid) => currentGroupIds.contains(gid));
                  }
                }
                return false;
              }).toList();
            }
            return events;
          },
        );
  }

  // ---------------- STREAM EVENTS (UPCOMING) ----------------
  Stream<List<EventModel>> streamUpcomingEvents() {
    final now = DateTime.now();
    return _firestore
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: now)
        .orderBy('date')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => EventModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // ---------------- GET EVENT ----------------
  Future<EventModel?> getEvent(String eventId) async {
    final doc = await _firestore.collection('events').doc(eventId).get();
    if (doc.exists) {
      return EventModel.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  // ---------------- GET EVENT COUNT ----------------
  Future<int> getEventCount() async {
    final snapshot = await _firestore.collection('events').count().get();
    return snapshot.count ?? 0;
  }
}

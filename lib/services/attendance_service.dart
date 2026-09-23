// lib/services/attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------- MARK ATTENDANCE ----------------
  Future<void> markAttendance({
    required String eventId,
    required String markedBy,
    required String markedByName,
    required String attendanceType, // 'whole_family' | 'sub_family'
    required String familyDocId,
    String subFamilyDocId = '',
    required String entityName,
    required int memberCount,
  }) async {
    // 1. Validate count range: 1 to 30
    if (memberCount < 1 || memberCount > 30) {
      throw Exception('Member count must be between 1 and 30.');
    }

    // 2. Fetch all attendance records for this event
    final allAttendanceSnap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .get();

    for (final doc in allAttendanceSnap.docs) {
      final rec = AttendanceModel.fromMap(doc.id, doc.data());

      // Rule A: If attendance was already marked for the whole family
      if (rec.familyDocId.isNotEmpty &&
          rec.familyDocId == familyDocId &&
          rec.attendanceType == 'whole_family') {
        throw Exception(
          'Attendance has already been marked for the Whole Family by ${rec.markedByName}.',
        );
      }

      // Rule B: If current user attempts whole family, but a sub-family already marked attendance
      if (attendanceType == 'whole_family' &&
          rec.familyDocId.isNotEmpty &&
          rec.familyDocId == familyDocId &&
          rec.attendanceType == 'sub_family') {
        throw Exception(
          'Attendance has already been marked by sub-family "${rec.entityName}" (by ${rec.markedByName}). Cannot mark for Whole Family.',
        );
      }

      // Rule C: If current user attempts sub-family, and THIS sub-family already marked attendance
      if (attendanceType == 'sub_family' &&
          subFamilyDocId.isNotEmpty &&
          rec.attendanceType == 'sub_family' &&
          (rec.subFamilyDocId == subFamilyDocId || rec.entityId == subFamilyDocId)) {
        throw Exception(
          'Attendance has already been marked for this sub-family by ${rec.markedByName}.',
        );
      }
    }

    // 3. Create new attendance record
    final attendance = AttendanceModel(
      id: '',
      eventId: eventId,
      markedBy: markedBy,
      markedByName: markedByName,
      attendanceType: attendanceType,
      entityId: attendanceType == 'whole_family' ? familyDocId : subFamilyDocId,
      entityName: entityName,
      familyDocId: familyDocId,
      subFamilyDocId: attendanceType == 'sub_family' ? subFamilyDocId : '',
      memberIds: [markedBy],
      memberCount: memberCount,
      markedAt: DateTime.now(),
      isCustomCount: true,
    );

    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .add(attendance.toMap());
  }

  // ---------------- GET ATTENDANCE FOR EVENT ----------------
  Stream<List<AttendanceModel>> getEventAttendance(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .orderBy('markedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ---------------- GET ATTENDANCE COUNT ----------------
  Future<int> getAttendanceCount(String eventId) async {
    final snapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .get();

    int totalCount = 0;
    for (final doc in snapshot.docs) {
      final count = doc.data()['memberCount'];
      totalCount += (count is int ? count : (count as num?)?.toInt() ?? 0);
    }
    return totalCount;
  }

  // ---------------- GET ATTENDANCE BY TYPE ----------------
  Future<Map<String, int>> getAttendanceByType(String eventId) async {
    final snapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .get();

    final Map<String, int> counts = {
      'whole_family': 0,
      'sub_family': 0,
    };

    for (final doc in snapshot.docs) {
      String type = doc.data()['attendanceType'] ?? 'whole_family';
      if (type == 'family') type = 'whole_family';
      if (type == 'subfamily') type = 'sub_family';

      final count = doc.data()['memberCount'] ?? 0;
      final countInt = count is int ? count : (count as num?)?.toInt() ?? 0;
      counts[type] = (counts[type] ?? 0) + countInt;
    }

    return counts;
  }

  // ---------------- UPDATE ATTENDANCE ----------------
  Future<void> updateAttendanceCount({
    required String eventId,
    required String attendanceId,
    required int newCount,
  }) async {
    if (newCount < 1 || newCount > 30) {
      throw Exception('Member count must be between 1 and 30.');
    }

    final doc = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .doc(attendanceId)
        .get();

    if (!doc.exists) throw Exception('Attendance record not found');

    await doc.reference.update({
      'memberCount': newCount,
      'isCustomCount': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- DELETE ATTENDANCE ----------------
  Future<void> deleteAttendance(String eventId, String attendanceId) async {
    final doc = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .doc(attendanceId)
        .get();

    if (!doc.exists) return;

    await doc.reference.delete();
  }
}


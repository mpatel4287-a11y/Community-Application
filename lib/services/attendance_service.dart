// lib/services/attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/member_model.dart';
import 'member_service.dart';
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MemberService _memberService = MemberService();

  // ---------------- MARK ATTENDANCE ----------------
  Future<void> markAttendance({
    required String eventId,
    required String markedBy,
    required String markedByName,
    required String attendanceType, // 'family' | 'subfamily' | 'firm'
    required String entityId, // familyDocId | subFamilyDocId | firmName
    required String entityName,
    int? customMemberCount,
  }) async {
    // 1. Check if this specific member is already accounted for in ANY attendance record for this event
    final allAttendanceSnap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .get();
        
    for (final doc in allAttendanceSnap.docs) {
      final memberIds = List<String>.from(doc.data()['memberIds'] ?? []);
      if (memberIds.contains(markedBy)) {
        throw Exception('You have already been marked for this event.');
      }
    }

    // 2. Get members based on attendance type
    List<MemberModel> members = [];
    
    if (attendanceType == 'family') {
      final allMembers = await _memberService.getAllMembers();
      members = allMembers.where((m) => m.familyDocId == entityId).toList();
    } else if (attendanceType == 'subfamily') {
      final pathParts = entityId.split('/');
      if (pathParts.length >= 2) {
        final familyDocId = pathParts[0];
        final subFamilyDocId = pathParts[1];
        final allMembers = await _memberService.getAllMembers();
        members = allMembers.where((m) => 
          m.familyDocId == familyDocId && m.subFamilyDocId == subFamilyDocId
        ).toList();
      }
    } else if (attendanceType == 'firm') {
      final allMembers = await _memberService.getAllMembers();
      members = allMembers.where((m) => 
        m.firms.any((firm) => firm['name'] == entityId)
      ).toList();
    }

    // 3. Check if ANY of the members in this group are already accounted for
    final accountedMemberIds = <String>{};
    for (final doc in allAttendanceSnap.docs) {
      accountedMemberIds.addAll(List<String>.from(doc.data()['memberIds'] ?? []));
    }
    
    final alreadyMarkedNames = members
        .where((m) => accountedMemberIds.contains(m.id))
        .map((m) => m.fullName)
        .toList();
        
    if (alreadyMarkedNames.isNotEmpty) {
      throw Exception('The following members are already marked for this event: ${alreadyMarkedNames.join(", ")}');
    }

    // 4. Validate custom count if provided
    if (customMemberCount != null && customMemberCount < members.length) {
      throw Exception('Custom count cannot be less than the total registered members (${members.length})');
    }

    // 5. Create new attendance
    final attendance = AttendanceModel(
      id: '',
      eventId: eventId,
      markedBy: markedBy,
      markedByName: markedByName,
      attendanceType: attendanceType,
      entityId: entityId,
      entityName: entityName,
      memberIds: members.map((m) => m.id).toList(),
      memberCount: customMemberCount ?? members.length,
      markedAt: DateTime.now(),
      isCustomCount: customMemberCount != null,
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
      totalCount += (count is int ? count : (count as num).toInt());
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
      'family': 0,
      'subfamily': 0,
      'firm': 0,
    };
    
    for (final doc in snapshot.docs) {
      final type = doc.data()['attendanceType'] ?? 'family';
      final count = doc.data()['memberCount'] ?? 0;
      final countInt = count is int ? count : (count as num).toInt();
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
    final doc = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .doc(attendanceId)
        .get();
        
    if (!doc.exists) throw Exception('Attendance record not found');
    
    final data = doc.data()!;
    final memberIds = List<String>.from(data['memberIds'] ?? []);
    
    if (newCount < memberIds.length) {
      throw Exception('Count cannot be less than members in group (${memberIds.length})');
    }

    if (newCount < memberIds.length) {
      throw Exception('Count cannot be less than members in group (${memberIds.length})');
    }

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

    if (!doc.exists) return;

    await doc.reference.delete();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'settings';
  static const String _globalDoc = 'global';

  // ---------------- ATTENDANCE TIME LIMIT ----------------
  Future<int> getAttendanceTimeLimit() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_globalDoc).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['attendanceTimeLimit'] ?? 60; // Default 60 minutes
      }
      return 60;
    } catch (e) {
      return 60; // Default on error
    }
  }

  Future<void> setAttendanceTimeLimit(int minutes) async {
    await _firestore.collection(_collection).doc(_globalDoc).set({
      'attendanceTimeLimit': minutes,
    }, SetOptions(merge: true));
  }
}

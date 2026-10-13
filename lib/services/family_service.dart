import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'counter_service.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  // ---------------- ADD FAMILY (Auto-generate 2-digit ID) ----------------
  Future<void> addFamily({
    required String familyName,
    required String password,
  }) async {
    if (password.length != 6) {
      throw Exception('Password must be 6 digits');
    }

    // Auto-generate 2-digit familyId
    final familyId = await _counterService.getNextFamilyId();

    await _firestore.collection('families').add({
      'familyId': familyId,
      'familyName': familyName,
      'password': password,
      'isAdmin': false,
      'isBlocked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- ADD FAMILY WITH MANUAL ID (Legacy - for migration) ----------------
  Future<void> addFamilyWithManualId({
    required String familyId,
    required String familyName,
    required String password,
  }) async {
    if (familyId.length != 2) {
      throw Exception('Family ID must be 2 digits');
    }
    if (password.length != 6) {
      throw Exception('Password must be 6 digits');
    }

    // Check duplicate familyId
    final existing = await _firestore
        .collection('families')
        .where('familyId', isEqualTo: familyId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Family ID already exists');
    }

    await _firestore.collection('families').add({
      'familyId': familyId,
      'familyName': familyName,
      'password': password,
      'isAdmin': false,
      'isBlocked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- UPDATE FAMILY ----------------
  Future<void> updateFamily({
    required String familyDocId,
    String? familyName,
    String? password,
    bool? isBlocked,
  }) async {
    final updates = <String, dynamic>{};

    if (familyName != null) updates['familyName'] = familyName;
    if (password != null) updates['password'] = password;
    if (isBlocked != null) updates['isBlocked'] = isBlocked;

    if (updates.isNotEmpty) {
      await _firestore.collection('families').doc(familyDocId).update(updates);
    }
  }

  // ---------------- DELETE FAMILY ----------------
  Future<void> deleteFamily(String familyDocId) async {
    // 1. Delete all sub-families and their members
    try {
      final subFamiliesSnap = await _firestore
          .collection('families')
          .doc(familyDocId)
          .collection('subfamilies')
          .get();

      for (final subDoc in subFamiliesSnap.docs) {
        // Delete all members in this sub-family
        try {
          final subMembersSnap =
              await subDoc.reference.collection('members').get();
          for (final mDoc in subMembersSnap.docs) {
            await mDoc.reference.delete();
          }
        } catch (e) {
          debugPrint('Error deleting sub-family members: $e');
        }
        // Delete sub-family doc
        await subDoc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting sub-families: $e');
    }

    // 2. Delete all members in families/{familyDocId}/members
    try {
      final membersSnap = await _firestore
          .collection('families')
          .doc(familyDocId)
          .collection('members')
          .get();

      for (final doc in membersSnap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting family members: $e');
    }

    // 3. Delete all groups of this family
    try {
      final groups = await _firestore
          .collection('families')
          .doc(familyDocId)
          .collection('groups')
          .get();

      for (final doc in groups.docs) {
        try {
          final messages = await doc.reference.collection('messages').get();
          for (final m in messages.docs) {
            await m.reference.delete();
          }
        } catch (_) {}
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting family groups: $e');
    }

    // 4. Delete counters in families/{familyDocId}/counters
    try {
      final countersSnap = await _firestore
          .collection('families')
          .doc(familyDocId)
          .collection('counters')
          .get();

      for (final doc in countersSnap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting counters: $e');
    }

    // 5. Delete member_update_requests for this family
    try {
      final reqs = await _firestore
          .collection('member_update_requests')
          .where('familyDocId', isEqualTo: familyDocId)
          .get();

      for (final doc in reqs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting update requests by familyDocId: $e');
    }

    // 6. Delete members from collectionGroup('members') where familyDocId == familyDocId
    try {
      final cgMembers = await _firestore
          .collectionGroup('members')
          .where('familyDocId', isEqualTo: familyDocId)
          .get();

      for (final doc in cgMembers.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error in collectionGroup members deletion: $e');
    }

    // 7. Delete from root members collection if any exist
    try {
      final rootMembers = await _firestore
          .collection('members')
          .where('familyDocId', isEqualTo: familyDocId)
          .get();

      for (final doc in rootMembers.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error in root members deletion: $e');
    }

    // 8. Delete the family document
    await _firestore.collection('families').doc(familyDocId).delete();
  }

  /// Delete families by matching name pattern (case-insensitive substring match, e.g. "patel", "demo")
  Future<int> deleteFamiliesByNamePattern(String namePattern) async {
    final query = await _firestore.collection('families').get();
    int count = 0;
    for (final doc in query.docs) {
      if (doc.id == '83288') continue; // Never delete admin root account
      final famName = (doc.data()['familyName'] ?? '').toString().toLowerCase();
      if (famName.contains(namePattern.toLowerCase())) {
        await deleteFamily(doc.id);
        count++;
      }
    }
    return count;
  }

  // ---------------- TOGGLE BLOCK FAMILY ----------------
  Future<void> toggleBlockFamily(String familyDocId) async {
    final doc = await _firestore.collection('families').doc(familyDocId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final isBlocked = data['isBlocked'] as bool? ?? false;
      await doc.reference.update({'isBlocked': !isBlocked});
    }
  }

  // ---------------- GET FAMILY BY ID ----------------
  Future<Map<String, dynamic>?> getFamilyByDocId(String familyDocId) async {
    final doc = await _firestore.collection('families').doc(familyDocId).get();
    if (doc.exists) {
      return {'id': doc.id, ...doc.data()!};
    }
    return null;
  }

  // ---------------- GET FAMILY BY FAMILY ID ----------------
  Future<Map<String, dynamic>?> getFamilyByFamilyId(int familyId) async {
    final query = await _firestore
        .collection('families')
        .where('familyId', isEqualTo: familyId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return {'id': doc.id, ...doc.data()};
    }
    return null;
  }

  // ---------------- STREAM FAMILIES (ALL) ----------------
  Stream<List<Map<String, dynamic>>> streamFamilies() {
    return _firestore
        .collection('families')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ---------------- STREAM FAMILIES (NON-ADMIN) ----------------
  Stream<List<Map<String, dynamic>>> streamNormalFamilies() {
    return _firestore
        .collection('families')
        .where('isAdmin', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ---------------- GET FAMILY COUNT ----------------
  Future<int> getFamilyCount() async {
    final snapshot = await _firestore
        .collection('families')
        .where('isAdmin', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET BLOCKED FAMILY COUNT ----------------
  Future<int> getBlockedFamilyCount() async {
    final snapshot = await _firestore
        .collection('families')
        .where('isAdmin', isEqualTo: false)
        .where('isBlocked', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET ACTIVE FAMILY COUNT ----------------
  Future<int> getActiveFamilyCount() async {
    final snapshot = await _firestore
        .collection('families')
        .where('isAdmin', isEqualTo: false)
        .where('isBlocked', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

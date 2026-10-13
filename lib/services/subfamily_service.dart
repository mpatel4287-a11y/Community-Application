import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subfamily_model.dart';
import 'counter_service.dart';

class SubFamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  // Get sub-families subcollection reference for a main family
  CollectionReference<Map<String, dynamic>> _getSubFamiliesCollection(
    String mainFamilyDocId,
  ) {
    return _firestore
        .collection('families')
        .doc(mainFamilyDocId)
        .collection('subfamilies');
  }

  // ---------------- ADD SUB-FAMILY ----------------
  Future<String> addSubFamily({
    required String mainFamilyDocId,
    required String mainFamilyId,
    required String mainFamilyName,
    required String subFamilyName,
    required String headOfFamily,
    String description = '',
    String seniority = '', // 'older' | 'younger' | ''
  }) async {
    final subFamilyRef = _getSubFamiliesCollection(mainFamilyDocId).doc();

    // Get auto-generated subFamilyId (2-digit)
    final subFamilyId = await _counterService.getNextSubFamilyId(
      mainFamilyDocId,
    );

    final subFamily = SubFamilyModel(
      id: subFamilyRef.id,
      subFamilyId: subFamilyId,
      mainFamilyDocId: mainFamilyDocId,
      mainFamilyId: mainFamilyId,
      mainFamilyName: mainFamilyName,
      subFamilyName: subFamilyName.trim(),
      headOfFamily: headOfFamily.trim(),
      description: description.trim(),
      memberCount: 0,
      isActive: true,
      seniority: seniority.trim().toLowerCase(),
      createdAt: DateTime.now(),
    );

    await subFamilyRef.set(subFamily.toMap());
    return subFamilyRef.id;
  }

  // ---------------- UPDATE SUB-FAMILY ----------------
  Future<void> updateSubFamily({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    String? subFamilyName,
    String? headOfFamily,
    String? description,
    bool? isActive,
    int? memberCount,
    String? seniority,
  }) async {
    final updates = <String, dynamic>{};

    if (subFamilyName != null) updates['subFamilyName'] = subFamilyName.trim();
    if (headOfFamily != null) updates['headOfFamily'] = headOfFamily.trim();
    if (description != null) updates['description'] = description.trim();
    if (isActive != null) updates['isActive'] = isActive;
    if (memberCount != null) updates['memberCount'] = memberCount;
    if (seniority != null) updates['seniority'] = seniority.trim().toLowerCase();

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _getSubFamiliesCollection(
        mainFamilyDocId,
      ).doc(subFamilyDocId).update(updates);
    }
  }

  // ---------------- DELETE SUB-FAMILY ----------------
  Future<void> deleteSubFamily({
    required String mainFamilyDocId,
    required String subFamilyDocId,
  }) async {
    // 1. Delete all members of this sub-family inside its direct subcollection:
    // families/{mainFamilyDocId}/subfamilies/{subFamilyDocId}/members
    try {
      final subMembers = await _getSubFamiliesCollection(mainFamilyDocId)
          .doc(subFamilyDocId)
          .collection('members')
          .get();

      for (final doc in subMembers.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Log or continue
    }

    // 2. Delete any members that might be in main family's members collection with this subFamilyDocId
    try {
      final mainMembers = await _firestore
          .collection('families')
          .doc(mainFamilyDocId)
          .collection('members')
          .where('subFamilyDocId', isEqualTo: subFamilyDocId)
          .get();

      for (final doc in mainMembers.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Log or continue
    }

    // 3. Delete any member_update_requests for this sub-family
    try {
      final reqs = await _firestore
          .collection('member_update_requests')
          .where('subFamilyDocId', isEqualTo: subFamilyDocId)
          .get();

      for (final doc in reqs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Log or continue
    }

    // 4. Safely attempt collectionGroup deletion in case index exists or works
    try {
      final cgMembers = await _firestore
          .collectionGroup('members')
          .where('subFamilyDocId', isEqualTo: subFamilyDocId)
          .get();

      for (final doc in cgMembers.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Collection group deletion can fail if index is absent, safely continue
    }

    // 5. Delete sub-family document itself
    await _getSubFamiliesCollection(
      mainFamilyDocId,
    ).doc(subFamilyDocId).delete();
  }

  /// Delete sub-families by name pattern (e.g., if searching across all main families)
  Future<int> deleteSubFamiliesByNamePattern(String namePattern) async {
    try {
      final query = await _firestore.collectionGroup('subfamilies').get();
      int count = 0;
      for (final doc in query.docs) {
        final subName = (doc.data()['subFamilyName'] ?? '').toString().toLowerCase();
        if (subName.contains(namePattern.toLowerCase())) {
          final mainFamilyDocId = doc.reference.parent.parent?.id ?? '';
          if (mainFamilyDocId.isNotEmpty) {
            await deleteSubFamily(mainFamilyDocId: mainFamilyDocId, subFamilyDocId: doc.id);
          } else {
            await doc.reference.delete();
          }
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ---------------- GET SUB-FAMILY ----------------
  Future<SubFamilyModel?> getSubFamily({
    required String mainFamilyDocId,
    required String subFamilyDocId,
  }) async {
    final doc = await _getSubFamiliesCollection(
      mainFamilyDocId,
    ).doc(subFamilyDocId).get();
    if (doc.exists) {
      return SubFamilyModel.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  // ---------------- GET SUB-FAMILIES BY MAIN FAMILY (ONE-TIME) ----------------
  Future<List<SubFamilyModel>> getSubFamilies(String mainFamilyDocId) async {
    final snapshot = await _getSubFamiliesCollection(mainFamilyDocId)
        .orderBy('subFamilyName')
        .get();
    
    return snapshot.docs
        .map((d) => SubFamilyModel.fromMap(d.id, d.data()))
        .toList();
  }

  // ---------------- GET SUB-FAMILIES BY MAIN FAMILY ----------------
  Stream<List<SubFamilyModel>> streamSubFamilies(String mainFamilyDocId) {
    return _getSubFamiliesCollection(mainFamilyDocId)
        .orderBy('subFamilyName')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubFamilyModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------------- GET ALL SUB-FAMILIES (ADMIN - from all main families) ----------------
  Stream<List<SubFamilyModel>> streamAllSubFamilies() {
    return _firestore
        .collectionGroup('subfamilies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubFamilyModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------------- UPDATE MEMBER COUNT ----------------
  Future<void> updateMemberCount({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required int count,
  }) async {
    await _getSubFamiliesCollection(mainFamilyDocId).doc(subFamilyDocId).update(
      {'memberCount': count, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  // ---------------- INCREMENT MEMBER COUNT ----------------
  Future<void> incrementMemberCount({
    required String mainFamilyDocId,
    required String subFamilyDocId,
  }) async {
    await _getSubFamiliesCollection(
      mainFamilyDocId,
    ).doc(subFamilyDocId).update({
      'memberCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- DECREMENT MEMBER COUNT ----------------
  Future<void> decrementMemberCount({
    required String mainFamilyDocId,
    required String subFamilyDocId,
  }) async {
    await _getSubFamiliesCollection(
      mainFamilyDocId,
    ).doc(subFamilyDocId).update({
      'memberCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- GET SUB-FAMILY COUNT (ALL MAIN FAMILIES) ----------------
  Future<int> getSubFamilyCount() async {
    final snapshot = await _firestore
        .collectionGroup('subfamilies')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET ACTIVE SUB-FAMILY COUNT (ALL MAIN FAMILIES) ----------------
  Future<int> getActiveSubFamilyCount() async {
    final snapshot = await _firestore
        .collectionGroup('subfamilies')
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET ALL SUB-FAMILIES (ONE-TIME FETCH - ALL MAIN FAMILIES) ----------------
  Future<List<SubFamilyModel>> getAllSubFamilies() async {
    final snapshot = await _firestore
        .collectionGroup('subfamilies')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((d) => SubFamilyModel.fromMap(d.id, d.data()))
        .toList();
  }

  // ---------------- SEARCH SUB-FAMILIES ----------------
  Stream<List<SubFamilyModel>> searchSubFamilies(String query) {
    return _firestore
        .collectionGroup('subfamilies')
        .orderBy('subFamilyName')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubFamilyModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------------- TOGGLE ACTIVE STATUS ----------------
  Future<void> toggleSubFamilyStatus({
    required String mainFamilyDocId,
    required String subFamilyDocId,
  }) async {
    final doc = await _getSubFamiliesCollection(
      mainFamilyDocId,
    ).doc(subFamilyDocId).get();
    if (doc.exists) {
      final isActive = doc['isActive'] as bool? ?? true;
      await doc.reference.update({
        'isActive': !isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

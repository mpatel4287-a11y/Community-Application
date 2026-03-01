// lib/services/member_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/member_model.dart';
import 'subfamily_service.dart'; // Added import

class MemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get members subcollection reference for a sub-family
  CollectionReference<Map<String, dynamic>> _getMembersCollection(
    String mainFamilyDocId,
    String subFamilyDocId,
  ) {
    return _firestore
        .collection('families')
        .doc(mainFamilyDocId)
        .collection('subfamilies')
        .doc(subFamilyDocId)
        .collection('members');
  }

  // ---------------- ADD MEMBER ----------------
  Future<void> addMember({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required String subFamilyId,
    required String familyId,
    required String familyName,
    required String fullName,
    required String surname,
    required String fatherName,
    required String motherName,
    required String gotra,
    required String gender, // Added
    required String birthDate,
    required String education, // Added
    required String bloodGroup,
    required String marriageStatus,
    required String nativeHome,
    required String phone,
    required String email, // Added
    required String address,
    required String googleMapLink,
    required String surdhan, // Added
    required List<Map<String, String>> firms,
    required String whatsapp,
    required String instagram,
    required String facebook,
    required List<String> tags,
    required String parentMid,
    required String password, // Added
    String photoUrl = '',
    String relationToHead = 'none',
    String subFamilyHeadRelationToMainHead = '',
  }) async {
    final age = MemberModel.calculateAge(birthDate);

    // Clean and truncate tags (max 15 chars)
    final cleanedTags = tags
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim().substring(0, t.length > 15 ? 15 : t.length))
        .toList();

    // Clean firms
    final cleanedFirms = firms
        .where((f) => (f['name'] ?? '').isNotEmpty)
        .map(
          (f) => {
            'name': f['name']!.trim(),
            'phone': (f['phone'] ?? '').trim(),
            'mapLink': (f['mapLink'] ?? '').trim(),
          },
        )
        .toList();

    // Create member in sub-family's subcollection
    final memberRef = _getMembersCollection(
      mainFamilyDocId,
      subFamilyDocId,
    ).doc();

    // Generate MID using new pattern: F{XX}-S{XX}-{XXX}
    final mid = MemberModel.generateMid(familyId, subFamilyId);

    final member = MemberModel(
      id: memberRef.id,
      mid: mid,
      familyDocId: mainFamilyDocId,
      subFamilyDocId: subFamilyDocId,
      subFamilyId: subFamilyId,
      familyId: familyId,
      familyName: familyName,
      fullName: fullName.trim(),
      surname: surname.trim(),
      fatherName: fatherName.trim(),
      motherName: motherName.trim(),
      gotra: gotra.trim(),
      gender: gender, // Added
      birthDate: birthDate.trim(),
      age: age,
      education: education.trim(), // Added
      bloodGroup: bloodGroup.trim(),
      marriageStatus: marriageStatus,
      nativeHome: nativeHome.trim(),
      phone: phone.trim(),
      email: email.trim(), // Added
      address: address.trim(),
      googleMapLink: googleMapLink.trim(),
      surdhan: surdhan.trim(), // Added
      firms: cleanedFirms,
      whatsapp: whatsapp.trim(),
      instagram: instagram.trim(),
      facebook: facebook.trim(),
      photoUrl: photoUrl.trim(),
      password: password, // Added
      role: 'member',
      tags: cleanedTags,
      isActive: true,
      parentMid: parentMid.trim(),
      relationToHead: relationToHead,
      subFamilyHeadRelationToMainHead: subFamilyHeadRelationToMainHead,
      createdAt: DateTime.now(),
    );

    // Batch write to ensure consistency (optional but recommended)
    // For now, sequential await to keep it simple and reuse existing services
    await memberRef.set(member.toMap());

    // Update member count in sub-family
    await SubFamilyService().incrementMemberCount(
      mainFamilyDocId: mainFamilyDocId,
      subFamilyDocId: subFamilyDocId,
    );
  }

  // ---------------- UPDATE MEMBER ----------------
  Future<void> updateMember({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required String memberId,
    required Map<String, dynamic> updates,
  }) async {
    // Handle tags cleaning
    if (updates.containsKey('tags')) {
      final List<String> tags = List<String>.from(updates['tags']);
      updates['tags'] = tags
          .where((t) => t.trim().isNotEmpty)
          .map((t) => t.trim().substring(0, t.length > 15 ? 15 : t.length))
          .toList();
    }

    if (updates.containsKey('birthDate')) {
      updates['age'] = MemberModel.calculateAge(updates['birthDate'] as String);
    }

    if (updates.containsKey('password')) {
      updates['password'] = updates['password'].toString().trim();
    }

    await _getMembersCollection(
      mainFamilyDocId,
      subFamilyDocId,
    ).doc(memberId).update(updates);
  }

  // ---------------- UPDATE MEMBER ROLE ----------------
  Future<void> updateMemberRole({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required String memberId,
    required String newRole,
  }) async {
    await _getMembersCollection(
      mainFamilyDocId,
      subFamilyDocId,
    ).doc(memberId).update({'role': newRole});
  }

  // ---------------- TOGGLE MEMBER STATUS ----------------
  Future<void> toggleMemberStatus({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required String memberId,
  }) async {
    final doc = await _getMembersCollection(mainFamilyDocId, subFamilyDocId)
        .doc(memberId)
        .get();
    if (doc.exists) {
      final isActive = doc.data()?['isActive'] as bool? ?? true;
      await doc.reference.update({'isActive': !isActive});
    }
  }

  // ---------------- DELETE MEMBER ----------------
  Future<void> deleteMember({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required String memberId,
  }) async {
    await _getMembersCollection(
      mainFamilyDocId,
      subFamilyDocId,
    ).doc(memberId).delete();

    // Update member count in sub-family
    await SubFamilyService().decrementMemberCount(
      mainFamilyDocId: mainFamilyDocId,
      subFamilyDocId: subFamilyDocId,
    );
  }

  // ---------------- GET MEMBER ----------------
  Future<MemberModel?> getMember({
    required String mainFamilyDocId,
    required String subFamilyDocId,
    required String memberId,
  }) async {
    final doc = await _getMembersCollection(
      mainFamilyDocId,
      subFamilyDocId,
    ).doc(memberId).get();
    if (doc.exists) {
      return MemberModel.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  // ---------------- GET MEMBERS BY SUB-FAMILY ----------------
  Stream<List<MemberModel>> streamSubFamilyMembers(
    String mainFamilyDocId,
    String subFamilyDocId,
  ) {
    return _getMembersCollection(mainFamilyDocId, subFamilyDocId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MemberModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------------- GET MEMBERS BY SUB-FAMILY (ONE-TIME) ----------------
  Future<List<MemberModel>> getSubFamilyMembers(
    String mainFamilyDocId,
    String subFamilyDocId,
  ) async {
    final snapshot = await _getMembersCollection(mainFamilyDocId, subFamilyDocId)
        .where('isActive', isEqualTo: true)
        .get();
        
    return snapshot.docs
        .map((d) => MemberModel.fromMap(d.id, d.data()))
        .toList();
  }

  // ---------------- GET ALL MEMBERS (ADMIN - from all families) ----------------
  Stream<List<MemberModel>> streamAllMembers() {
    // For admin view, we need to use collection group query
    // This will query all 'members' subcollections across all families
    return _firestore
        .collectionGroup('members')
        .snapshots()

        .map(
          (snap) => snap.docs
              .map((d) => MemberModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------------- SEARCH MEMBERS ----------------
  Stream<List<MemberModel>> searchMembers(String query) {
    if (query.isEmpty) return Stream.value([]);
    
    final q = query.trim();
    final upperQ = q.toUpperCase();

    // Prefix search for name (Firestore is case-sensitive)
    final nameStream = _firestore
        .collectionGroup('members')
        .where('fullName', isGreaterThanOrEqualTo: q)
        .where('fullName', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .snapshots();

    // Prefix search for MID
    final midStream = _firestore
        .collectionGroup('members')
        .where('mid', isGreaterThanOrEqualTo: upperQ)
        .where('mid', isLessThanOrEqualTo: '$upperQ\uf8ff')
        .limit(20)
        .snapshots();

    return Rx.combineLatest2<QuerySnapshot<Map<String, dynamic>>, QuerySnapshot<Map<String, dynamic>>, List<MemberModel>>(
      nameStream,
      midStream,
      (snap1, snap2) {
        final results = <String, MemberModel>{};
        for (var d in snap1.docs) {
          results[d.id] = MemberModel.fromMap(d.id, d.data());
        }
        for (var d in snap2.docs) {
          results[d.id] = MemberModel.fromMap(d.id, d.data());
        }
        return results.values.toList();
      },
    );
  }

  // ---------------- TAG FILTER ----------------
  Stream<List<MemberModel>> filterByTag(String tag) {
    // Use collection group for cross-family tag filter
    return _firestore
        .collectionGroup('members')
        .where('tags', arrayContains: tag)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MemberModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------------- GET MEMBER COUNT (ALL FAMILIES) ----------------
  Future<int> getMemberCount() async {
    final snapshot = await _firestore.collectionGroup('members').count().get();
    return snapshot.count ?? 0;
  }

  // ---------------- STREAM MEMBER COUNT (ALL FAMILIES) ----------------
  Stream<int> streamMemberCount() {
    return _firestore
        .collectionGroup('members')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ---------------- GET UNMARRIED COUNT (ALL FAMILIES) ----------------
  Future<int> getUnmarriedCount() async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('marriageStatus', isEqualTo: 'unmarried')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET ACTIVE MEMBER COUNT (ALL FAMILIES) ----------------
  Future<int> getActiveMemberCount() async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET ALL UNIQUE TAGS (ALL FAMILIES) ----------------
  Future<List<String>> getAllTags() async {
    final snapshot = await _firestore.collectionGroup('members').get();
    final allTags = <String>{};
    for (final doc in snapshot.docs) {
      final tags = List<String>.from(doc['tags'] ?? []);
      allTags.addAll(tags);
    }
    return allTags.toList()..sort();
  }

  // ---------------- GET ALL MEMBERS (ONE-TIME FETCH - ALL FAMILIES) ----------------
  Future<List<MemberModel>> getAllMembers() async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .get();

    return snapshot.docs
        .map((d) => MemberModel.fromMap(d.id, d.data()))
        .toList();
  }

  // ---------------- GET MEMBERS BY MULTIPLE MIDs ----------------
  Future<List<MemberModel>> getMembersByMids(List<String> mids) async {
    if (mids.isEmpty) return [];
    
    // Firestore whereIn has a limit of 30 elements
    // Split into chunks of 30
    List<List<String>> chunks = [];
    for (var i = 0; i < mids.length; i += 30) {
      chunks.add(mids.sublist(i, i + 30 > mids.length ? mids.length : i + 30));
    }

    List<MemberModel> allFound = [];
    for (var chunk in chunks) {
      final snapshot = await _firestore
          .collectionGroup('members')
          .where('mid', whereIn: chunk)
          .get();
      allFound.addAll(snapshot.docs.map((d) => MemberModel.fromMap(d.id, d.data())));
    }
    
    return allFound;
  }


  // ---------------- GET MARRIED COUNT (ALL FAMILIES) ----------------
  Future<int> getMarriedCount() async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('marriageStatus', isEqualTo: 'married')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ---------------- GET NEW MEMBERS THIS MONTH (ALL FAMILIES) ----------------
  Future<int> getNewMembersThisMonth() async {
    // Note: This requires a COLLECTION_GROUP_ASC index for 'createdAt'
    // To avoid crashes if the index is missing, we can fetch all and filter or return 0
    // The dashboard already calculates this in-memory from the full member list.
    return 0; 
  }

  // ---------------- GET MEMBER BY MID (3-digit) ----------------
  Future<MemberModel?> getMemberByMid(String mid) async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('mid', isEqualTo: mid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return MemberModel.fromMap(doc.id, doc.data());
    }
    return null;
  }

  // ---------------- GET UNIQUE MEMBER COUNT FOR SUB-FAMILY ----------------
  Future<int> getSubFamilyMemberCount(
    String mainFamilyDocId,
    String subFamilyDocId,
  ) async {
    final snapshot = await _getMembersCollection(
      mainFamilyDocId,
      subFamilyDocId,
    ).count().get();
    return snapshot.count ?? 0;
  }

  // ---------------- CHECK IF SUB-FAMILY HAS HEAD ----------------
  Future<bool> hasSubFamilyHead(String mainFamilyDocId, String subFamilyDocId) async {
    final snapshot = await _firestore
        .collection('families')
        .doc(mainFamilyDocId)
        .collection('subfamilies')
        .doc(subFamilyDocId)
        .collection('members')
        .where('relationToHead', isEqualTo: 'head')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ---------------- GET ALL UNIQUE FIRM NAMES (ALL FAMILIES) ----------------
  Future<List<String>> getAllFirmNames() async {
    final snapshot = await _firestore.collectionGroup('members').get();
    final allFirms = <String>{};
    for (final doc in snapshot.docs) {
      final firms = List<dynamic>.from(doc.data()['firms'] ?? []);
      for (final firm in firms) {
        final name = (firm['name'] as String? ?? '').trim();
        if (name.isNotEmpty) {
          allFirms.add(name);
        }
      }
    }
    return allFirms.toList()..sort();
  }
}

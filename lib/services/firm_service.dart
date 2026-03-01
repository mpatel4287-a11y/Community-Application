// lib/services/firm_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firm_model.dart';
import '../models/sub_firm_model.dart';

class FirmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'firms';

  // ==========================================
  // FIRMS
  // ==========================================

  Future<void> createFirm({
    required String name,
  }) async {
    final docRef = _firestore.collection(_collectionName).doc();
    final firm = FirmModel(
      id: docRef.id,
      name: name,
      createdAt: DateTime.now(),
    );

    await docRef.set(firm.toMap());
  }

  Future<void> updateFirm(String id, {required String name}) async {
    await _firestore.collection(_collectionName).doc(id).update({
      'name': name,
    });
  }

  Future<void> deleteFirm(String id) async {
    // Delete all associated sub-firms first
    final subFirmsSnap = await _firestore
        .collection(_collectionName)
        .doc(id)
        .collection('sub_firms')
        .get();

    for (var doc in subFirmsSnap.docs) {
      await doc.reference.delete();
    }

    // Delete the firm itself
    await _firestore.collection(_collectionName).doc(id).delete();
  }

  Stream<List<FirmModel>> getFirmsStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FirmModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<FirmModel>> getAllFirms() async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .orderBy('name')
        .get();
        
    return snapshot.docs
        .map((doc) => FirmModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ==========================================
  // SUB-FIRMS
  // ==========================================

  Future<void> createSubFirm({
    required String firmId,
    required String name,
    required String location,
    required String contactNumber,
    required String contactName,
  }) async {
    final subCollectionRef = _firestore
        .collection(_collectionName)
        .doc(firmId)
        .collection('sub_firms');
        
    final docRef = subCollectionRef.doc();
    
    final subFirm = SubFirmModel(
      id: docRef.id,
      firmId: firmId,
      name: name,
      location: location,
      contactNumber: contactNumber,
      contactName: contactName,
      createdAt: DateTime.now(),
    );

    await docRef.set(subFirm.toMap());
  }

  Future<void> updateSubFirm(
    String firmId,
    String subFirmId, {
    String? name,
    String? location,
    String? contactNumber,
    String? contactName,
  }) async {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (location != null) map['location'] = location;
    if (contactNumber != null) map['contactNumber'] = contactNumber;
    if (contactName != null) map['contactName'] = contactName;

    if (map.isNotEmpty) {
      await _firestore
          .collection(_collectionName)
          .doc(firmId)
          .collection('sub_firms')
          .doc(subFirmId)
          .update(map);
    }
  }

  Future<void> deleteSubFirm(String firmId, String subFirmId) async {
    await _firestore
        .collection(_collectionName)
        .doc(firmId)
        .collection('sub_firms')
        .doc(subFirmId)
        .delete();
  }

  Stream<List<SubFirmModel>> getSubFirmsStream(String firmId) {
    return _firestore
        .collection(_collectionName)
        .doc(firmId)
        .collection('sub_firms')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SubFirmModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<SubFirmModel>> getAllSubFirms(String firmId) async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .doc(firmId)
        .collection('sub_firms')
        .orderBy('name')
        .get();
        
    return snapshot.docs
        .map((doc) => SubFirmModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}

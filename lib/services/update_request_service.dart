// lib/services/update_request_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/member_update_request_model.dart';
import 'photo_service.dart';
import 'member_service.dart';

class UpdateRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PhotoService _photoService = PhotoService();
  final MemberService _memberService = MemberService();

  static const String _collectionName = 'member_update_requests';

  // ---------------- SUBMIT REQUEST ----------------
  Future<String> submitRequest({
    required MemberUpdateRequestModel request,
    XFile? newPhotoFile,
    Uint8List? newPhotoBytes,
  }) async {
    try {
      String uploadedPhotoUrl = request.newPhotoUrl;

      // Upload image if attached
      if (newPhotoBytes != null || newPhotoFile != null) {
        final photoUrl = await _photoService.uploadProfilePhoto(
          memberId: request.memberId.isNotEmpty ? request.memberId : request.memberMid,
          image: newPhotoFile,
          bytes: newPhotoBytes,
        );

        if (photoUrl != null && photoUrl.isNotEmpty) {
          uploadedPhotoUrl = photoUrl;
        }
      }

      final docRef = _firestore.collection(_collectionName).doc();

      final fullRequest = MemberUpdateRequestModel(
        id: docRef.id,
        memberId: request.memberId,
        memberMid: request.memberMid,
        memberName: request.memberName,
        familyDocId: request.familyDocId,
        subFamilyDocId: request.subFamilyDocId,
        familyName: request.familyName,
        requestedByPhone: request.requestedByPhone,
        requestType: request.requestType,
        title: request.title,
        description: request.description,
        fieldUpdates: request.fieldUpdates,
        currentPhotoUrl: request.currentPhotoUrl,
        newPhotoUrl: uploadedPhotoUrl,
        status: 'pending',
        adminNote: '',
        createdAt: DateTime.now(),
      );

      await docRef.set(fullRequest.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error submitting update request: $e');
      rethrow;
    }
  }

  // ---------------- STREAM USER REQUESTS ----------------
  Stream<List<MemberUpdateRequestModel>> streamUserRequests(String memberId, {String? phone}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collectionName);

    if (memberId.isNotEmpty) {
      query = query.where('memberId', isEqualTo: memberId);
    } else if (phone != null && phone.isNotEmpty) {
      query = query.where('requestedByPhone', isEqualTo: phone);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => MemberUpdateRequestModel.fromMap(doc.id, doc.data()))
          .toList();
      // Sort in-memory to avoid compound index requirements
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---------------- STREAM ALL REQUESTS (FOR ADMIN) ----------------
  Stream<List<MemberUpdateRequestModel>> streamAllRequests({String? statusFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collectionName);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => MemberUpdateRequestModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---------------- APPLY & APPROVE REQUEST (ADMIN) ----------------
  Future<void> applyAndApproveRequest({
    required MemberUpdateRequestModel request,
    required Map<String, dynamic> approvedUpdates,
    String? approvedPhotoUrl,
    String adminNote = '',
  }) async {
    try {
      // Handle account deletion request specifically
      if (request.requestType == 'account_deletion') {
        final memberIdToDel = request.memberId.isNotEmpty ? request.memberId : request.memberMid;
        await _memberService.deleteMember(
          mainFamilyDocId: request.familyDocId,
          subFamilyDocId: request.subFamilyDocId,
          memberId: memberIdToDel,
        );

        // Also sweep any matching docs by MID across collectionGroup
        if (request.memberMid.isNotEmpty) {
          try {
            final q = await _firestore
                .collectionGroup('members')
                .where('mid', isEqualTo: request.memberMid)
                .get();
            for (final doc in q.docs) {
              await doc.reference.delete();
            }
          } catch (_) {}
        }

        // Mark request as approved (account deleted)
        final Map<String, dynamic> requestUpdates = {
          'status': 'approved',
          'adminNote': adminNote.isNotEmpty ? adminNote : 'Account permanently deleted by Admin',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _firestore.collection(_collectionName).doc(request.id).update(requestUpdates);
        return;
      }

      final Map<String, dynamic> memberUpdates = Map<String, dynamic>.from(approvedUpdates);

      // Handle photo update
      if (approvedPhotoUrl != null && approvedPhotoUrl.isNotEmpty) {
        memberUpdates['photoUrl'] = approvedPhotoUrl;
      } else if (request.newPhotoUrl.isNotEmpty && (memberUpdates['photo_update_requested'] == true || request.requestType == 'photo_update')) {
        memberUpdates['photoUrl'] = request.newPhotoUrl;
      }

      // Remove internal helper keys
      memberUpdates.remove('photo_update_requested');

      // 1. Update the actual member document in Firestore
      if (memberUpdates.isNotEmpty && request.memberId.isNotEmpty && request.familyDocId.isNotEmpty) {
        await _memberService.updateMember(
          mainFamilyDocId: request.familyDocId,
          subFamilyDocId: request.subFamilyDocId,
          memberId: request.memberId,
          updates: memberUpdates,
        );
      }

      // 2. Mark the request as approved
      final Map<String, dynamic> requestUpdates = {
        'status': 'approved',
        'adminNote': adminNote,
        'fieldUpdates': approvedUpdates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approvedPhotoUrl != null && approvedPhotoUrl.isNotEmpty) {
        requestUpdates['newPhotoUrl'] = approvedPhotoUrl;
      }

      await _firestore.collection(_collectionName).doc(request.id).update(requestUpdates);
    } catch (e) {
      debugPrint('Error approving and applying update request: $e');
      rethrow;
    }
  }

  // ---------------- REJECT REQUEST (ADMIN) ----------------
  Future<void> rejectRequest({
    required String requestId,
    String adminNote = '',
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(requestId).update({
        'status': 'rejected',
        'adminNote': adminNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error rejecting update request: $e');
      rethrow;
    }
  }

  // ---------------- UPDATE REQUEST STATUS ----------------
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String adminNote = '',
  }) async {
    await _firestore.collection(_collectionName).doc(requestId).update({
      'status': status,
      'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- DELETE REQUEST ----------------
  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection(_collectionName).doc(requestId).delete();
  }

  // ---------------- CANCEL REQUEST (BY USER) ----------------
  Future<void> cancelRequest(String requestId) async {
    await _firestore.collection(_collectionName).doc(requestId).delete();
  }

  // ---------------- GET PENDING DELETION REQUEST ----------------
  Future<MemberUpdateRequestModel?> getPendingDeletionRequest({
    required String memberId,
    String? memberMid,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collectionName)
          .where('requestType', isEqualTo: 'account_deletion')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in snap.docs) {
        final req = MemberUpdateRequestModel.fromMap(doc.id, doc.data());
        if (req.memberId == memberId || (memberMid != null && memberMid.isNotEmpty && req.memberMid == memberMid)) {
          return req;
        }
      }
    } catch (e) {
      debugPrint('Error getting pending deletion request: $e');
    }
    return null;
  }
}


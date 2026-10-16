// test/account_deletion_and_firms_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_update_request_model.dart';
import 'package:comm_app/models/member_model.dart';
import 'package:comm_app/utils/member_sort_helper.dart';

void main() {
  group('Account Deletion Request Tests', () {
    test('MemberUpdateRequestModel correctly serializes and deserializes account_deletion request', () {
      final now = DateTime(2026, 10, 16, 12, 0);
      final req = MemberUpdateRequestModel(
        id: 'del_req_123',
        memberId: 'mem_456',
        memberMid: 'F-001-S01-001',
        memberName: 'Pravin Patel',
        familyDocId: 'fam_doc_1',
        subFamilyDocId: 'sub_doc_1',
        familyName: 'Patel Family',
        requestedByPhone: '9876543210',
        requestType: 'account_deletion',
        title: 'Permanent Account Deletion Request',
        description: 'User requested permanent account deletion under Data Safety policy.',
        status: 'pending',
        adminNote: '',
        createdAt: now,
      );

      final map = req.toMap();
      expect(map['requestType'], 'account_deletion');
      expect(map['title'], 'Permanent Account Deletion Request');
      expect(map['status'], 'pending');
      expect(map['memberMid'], 'F-001-S01-001');

      final fromMapReq = MemberUpdateRequestModel.fromMap('del_req_123', map);
      expect(fromMapReq.requestType, 'account_deletion');
      expect(fromMapReq.status, 'pending');
      expect(fromMapReq.memberMid, 'F-001-S01-001');
      expect(fromMapReq.memberName, 'Pravin Patel');
    });

    test('Account deletion request rejected leaves account intact with admin note', () {
      final map = {
        'id': 'del_req_789',
        'memberId': 'mem_456',
        'memberMid': 'F-001-S01-001',
        'memberName': 'Pravin Patel',
        'familyDocId': 'fam_doc_1',
        'subFamilyDocId': 'sub_doc_1',
        'familyName': 'Patel Family',
        'requestedByPhone': '9876543210',
        'requestType': 'account_deletion',
        'title': 'Permanent Account Deletion Request',
        'description': 'Requested by mistake',
        'status': 'rejected',
        'adminNote': 'Account deletion rejected by admin committee. Account remains normal.',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final req = MemberUpdateRequestModel.fromMap('del_req_789', map);
      expect(req.status, 'rejected');
      expect(req.adminNote, contains('Account remains normal'));
    });
  });

  group('PDF Export Order Vise Older to Younger Tests', () {
    test('MemberSortHelper sorts members older to younger within hierarchy', () {
      final head = MemberModel.empty().copyWith(
        id: 'h1',
        mid: 'F-001-S01-001',
        fullName: 'Ramesh Patel (Head)',
        relationToHead: 'Head',
        birthDate: '01/01/1960',
        gender: 'Male',
        spouseMid: 'F-001-S01-002',
      );

      final spouse = MemberModel.empty().copyWith(
        id: 's1',
        mid: 'F-001-S01-002',
        fullName: 'Savitaben Patel (Spouse)',
        relationToHead: 'Wife',
        birthDate: '01/01/1964',
        gender: 'Female',
        spouseMid: 'F-001-S01-001',
      );

      final youngerSon = MemberModel.empty().copyWith(
        id: 'c2',
        mid: 'F-001-S01-005',
        fullName: 'Chirag Patel (Younger Son)',
        relationToHead: 'Son',
        parentMid: 'F-001-S01-001',
        birthDate: '01/01/1998',
        gender: 'Male',
      );

      final elderSon = MemberModel.empty().copyWith(
        id: 'c1',
        mid: 'F-001-S01-003',
        fullName: 'Amit Patel (Elder Son)',
        relationToHead: 'Son',
        parentMid: 'F-001-S01-001',
        birthDate: '01/01/1992',
        gender: 'Male',
      );

      // Unordered list
      final List<MemberModel> rawList = [youngerSon, spouse, elderSon, head];
      final sorted = MemberSortHelper.sortMembers(rawList);

      // 1. Head
      expect(sorted[0].id, 'h1');
      // 2. Head's Spouse
      expect(sorted[1].id, 's1');
      // 3. Elder son (born 1992)
      expect(sorted[2].id, 'c1');
      // 4. Younger son (born 1998)
      expect(sorted[3].id, 'c2');
    });
  });
}

// test/full_member_update_request_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_update_request_model.dart';
import 'package:comm_app/models/member_model.dart';

void main() {
  group('Full Member Update Request Tests', () {
    test('MemberUpdateRequestModel serializes and deserializes all requested fields properly', () {
      final now = DateTime(2026, 10, 20, 10, 0);
      final fieldUpdates = {
        'fullName': 'Jayeshkumar',
        'surname': 'Patel',
        'fatherName': 'Rameshbhai',
        'motherName': 'Savitaben',
        'gender': 'male',
        'birthDate': '15/06/1990',
        'bloodGroup': 'B+',
        'marriageStatus': 'married',
        'nativeHome': 'Surat',
        'gotra': 'Kashyap',
        'education': 'B.Tech IT',
        'surdhan': 'Jay Ambe',
        'phone': '9876543210',
        'whatsapp': '9876543210',
        'email': 'jayesh@example.com',
        'address': '123 Patel Street, Ramanagara',
        'googleMapLink': 'https://maps.google.com/?q=12.123,77.123',
        'instagram': 'jayesh_patel',
        'facebook': 'https://facebook.com/jayesh.patel',
        'snapchat': 'jayesh_patel_snap',
        'firms': [
          {'name': 'Patel Textiles', 'phone': '9988776655', 'mapLink': 'https://maps.google.com/tex'},
          {'name': 'Patel Agro Exports', 'phone': '9876512345', 'mapLink': 'https://maps.google.com/agro'},
        ],
        'relationToHead': 'son',
        'parentMid': 'F01-S01-001',
        'spouseMid': 'F01-S01-003',
        'isDeceased': false,
        'tod': '',
      };

      final req = MemberUpdateRequestModel(
        id: 'req_full_001',
        memberId: 'mem_123',
        memberMid: 'F01-S01-002',
        memberName: 'Jayeshkumar Patel',
        familyDocId: 'fam_01',
        subFamilyDocId: 'sub_01',
        familyName: 'Patel Family',
        requestedByPhone: '9876543210',
        requestType: 'all',
        title: 'Full Profile Update Request',
        description: 'Updated firms, social media handles, and personal info.',
        fieldUpdates: fieldUpdates,
        status: 'pending',
        createdAt: now,
      );

      final map = req.toMap();
      expect(map['requestType'], 'all');
      expect(map['title'], 'Full Profile Update Request');
      expect(map['status'], 'pending');
      expect(map['fieldUpdates'], isA<Map>());
      expect(map['fieldUpdates']['instagram'], 'jayesh_patel');
      expect(map['fieldUpdates']['snapchat'], 'jayesh_patel_snap');
      expect(map['fieldUpdates']['firms'], hasLength(2));
      expect(map['fieldUpdates']['firms'][0]['name'], 'Patel Textiles');
      expect(map['fieldUpdates']['firms'][1]['name'], 'Patel Agro Exports');
      expect(map['fieldUpdates']['relationToHead'], 'son');
      expect(map['fieldUpdates']['parentMid'], 'F01-S01-001');

      final fromMapReq = MemberUpdateRequestModel.fromMap('req_full_001', map);
      expect(fromMapReq.requestType, 'all');
      expect(fromMapReq.fieldUpdates['fullName'], 'Jayeshkumar');
      expect(fromMapReq.fieldUpdates['snapchat'], 'jayesh_patel_snap');
      expect(fromMapReq.fieldUpdates['firms'], isA<List>());
      expect((fromMapReq.fieldUpdates['firms'] as List).length, 2);
      expect(fromMapReq.fieldUpdates['firms'][0]['phone'], '9988776655');
      expect(fromMapReq.fieldUpdates['surdhan'], 'Jay Ambe');
      expect(fromMapReq.fieldUpdates['isDeceased'], false);
    });

    test('MemberUpdateRequestModel serializes deceased updates with tod', () {
      final now = DateTime(2026, 10, 20, 10, 0);
      final fieldUpdates = {
        'fullName': 'Late Somabhai Patel',
        'isDeceased': true,
        'tod': '10/04/2018',
        'relationToHead': 'father',
      };

      final req = MemberUpdateRequestModel(
        id: 'req_dec_001',
        memberId: 'mem_elder',
        memberMid: 'F01-S01-000',
        memberName: 'Somabhai Patel',
        familyDocId: 'fam_01',
        subFamilyDocId: 'sub_01',
        familyName: 'Patel Family',
        requestedByPhone: '9876543210',
        requestType: 'lineage_info',
        title: 'Mark as Late and Set Date of Death',
        description: 'Update father record to Late.',
        fieldUpdates: fieldUpdates,
        status: 'pending',
        createdAt: now,
      );

      final map = req.toMap();
      final parsed = MemberUpdateRequestModel.fromMap('req_dec_001', map);
      expect(parsed.fieldUpdates['isDeceased'], true);
      expect(parsed.fieldUpdates['tod'], '10/04/2018');
      expect(parsed.fieldUpdates['relationToHead'], 'father');
    });

    test('MemberUpdateRequestModel serializes social_media request category', () {
      final req = MemberUpdateRequestModel(
        id: 'req_soc_001',
        memberId: 'mem_123',
        memberMid: 'F01-S01-002',
        memberName: 'Jayesh Patel',
        familyDocId: 'fam_01',
        subFamilyDocId: 'sub_01',
        familyName: 'Patel Family',
        requestedByPhone: '9876543210',
        requestType: 'social_media',
        title: 'Social Media Handles Update',
        description: 'Added Snapchat and updated Instagram.',
        fieldUpdates: {
          'whatsapp': '9876543210',
          'instagram': 'jayesh_gram',
          'facebook': 'jayesh.fb',
          'snapchat': 'jayesh_snap',
        },
        status: 'pending',
        createdAt: DateTime.now(),
      );

      final map = req.toMap();
      final parsed = MemberUpdateRequestModel.fromMap('req_soc_001', map);
      expect(parsed.requestType, 'social_media');
      expect(parsed.fieldUpdates['snapchat'], 'jayesh_snap');
      expect(parsed.fieldUpdates['instagram'], 'jayesh_gram');
    });
  });
}

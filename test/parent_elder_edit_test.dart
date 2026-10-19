import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_model.dart';

void main() {
  group('Parent Elders Edit & Display Logic Tests', () {
    test('Deceased father and mother retain all fields required for editing', () {
      final lateFather = MemberModel.empty().copyWith(
        id: 'father_doc_1',
        familyDocId: 'main_fam_123',
        subFamilyDocId: '',
        subFamilyId: '',
        mid: 'MID101',
        fullName: 'Akhai Karamsi Bhavani',
        gender: 'male',
        relationToHead: 'father',
        isDeceased: true,
        tod: '15/08/2010',
        isCommon: true,
      );

      final lateMother = MemberModel.empty().copyWith(
        id: 'mother_doc_1',
        familyDocId: 'main_fam_123',
        subFamilyDocId: '',
        subFamilyId: '',
        mid: 'MID102',
        fullName: 'Ganga Akhai Bhavani',
        gender: 'female',
        relationToHead: 'mother',
        isDeceased: true,
        tod: '10/02/2015',
        isCommon: true,
      );

      expect(lateFather.isLate, isTrue);
      expect(lateFather.isDeceased, isTrue);
      expect(lateFather.fullName, 'Akhai Karamsi Bhavani');
      expect(lateFather.familyDocId, 'main_fam_123');
      expect(lateFather.subFamilyDocId, '');

      expect(lateMother.isLate, isTrue);
      expect(lateMother.isDeceased, isTrue);
      expect(lateMother.fullName, 'Ganga Akhai Bhavani');
      expect(lateMother.familyDocId, 'main_fam_123');
      expect(lateMother.subFamilyDocId, '');
    });

    test('Filter logic: Deceased members are kept for Common Elders (_isCommon=true) but hidden for regular sub-families (_isCommon=false)', () {
      final membersData = [
        {'id': 'm1', 'fullName': 'Active Member', 'isDeceased': false, 'tod': ''},
        {'id': 'm2', 'fullName': 'Late Akhai', 'isDeceased': true, 'tod': '2010'},
        {'id': 'm3', 'fullName': 'Late Ganga', 'isDeceased': false, 'tod': '2015'}, // TOD indicates deceased
      ];

      bool shouldKeepMember({
        required Map<String, dynamic> data,
        required bool isCommon,
      }) {
        final isDeceased = data['isDeceased'] == true ||
            (data['tod'] != null && data['tod'].toString().trim().isNotEmpty);
        if (!isCommon && isDeceased) return false;
        return true;
      }

      // For regular subfamily (isCommon = false), deceased members must be hidden
      final regularResults = membersData.where((m) => shouldKeepMember(data: m, isCommon: false)).toList();
      expect(regularResults.length, 1);
      expect(regularResults.first['id'], 'm1');

      // For Common Elders / Manage Elders (isCommon = true), deceased members must be shown for editing & management
      final commonResults = membersData.where((m) => shouldKeepMember(data: m, isCommon: true)).toList();
      expect(commonResults.length, 3);
      expect(commonResults.map((m) => m['id']).toList(), ['m1', 'm2', 'm3']);
    });

    test('Alive father and mother models support direct edit action', () {
      final activeFather = MemberModel.empty().copyWith(
        id: 'active_father_1',
        familyDocId: 'main_fam_456',
        subFamilyDocId: '',
        subFamilyId: '',
        mid: 'MID201',
        fullName: 'Ramesh Karamsi Bhavani',
        gender: 'male',
        phone: '9876543210',
        relationToHead: 'father',
        isDeceased: false,
        isCommon: true,
      );

      expect(activeFather.isLate, isFalse);
      expect(activeFather.isDeceased, isFalse);
      expect(activeFather.phone, '9876543210');
      expect(activeFather.id, 'active_father_1');
    });
  });
}

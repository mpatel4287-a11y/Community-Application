import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_model.dart';
import 'package:comm_app/services/export_service.dart';

void main() {
  test('ExportField.familyId resolves true community YSK Family ID across family members', () {
    final memberWithSerial = MemberModel(
      id: 'm1',
      mid: 'F-001-S01-101',
      familyDocId: 'fam_doc_1',
      subFamilyDocId: 'sub_doc_1',
      subFamilyId: '01',
      familyId: '08', // Serial 2-digit counter
      familyName: 'Lalji Family',
      fullName: 'Ramesh',
      surname: 'Patel',
      fatherName: 'Lalji',
      motherName: 'Devi',
      gotra: 'Kashyap',
      gender: 'male',
      birthDate: '01/01/1990',
      education: 'Graduate',
      bloodGroup: 'B+',
      marriageStatus: 'married',
      nativeHome: 'Ramanagara',
      phone: '9876543210',
      email: '',
      address: '',
      googleMapLink: '',
      surdhan: '',
      firms: [],
      whatsapp: '',
      instagram: '',
      facebook: '',
      photoUrl: '',
      password: '',
      role: 'member',
      tags: [],
      isActive: true,
      parentMid: '',
      createdAt: DateTime.now(),
    );

    final memberWithYskId = MemberModel(
      id: 'm2',
      mid: 'F-001-S01-102',
      familyDocId: 'fam_doc_1',
      subFamilyDocId: 'sub_doc_1',
      subFamilyId: '01',
      familyId: '723124', // Community YSK Family ID
      familyName: 'Lalji Family',
      fullName: 'Suresh',
      surname: 'Patel',
      fatherName: 'Lalji',
      motherName: 'Devi',
      gotra: 'Kashyap',
      gender: 'male',
      birthDate: '01/01/1995',
      education: 'Graduate',
      bloodGroup: 'B+',
      marriageStatus: 'unmarried',
      nativeHome: 'Ramanagara',
      phone: '9876543211',
      email: '',
      address: '',
      googleMapLink: '',
      surdhan: '',
      firms: [],
      whatsapp: '',
      instagram: '',
      facebook: '',
      photoUrl: '',
      password: '',
      role: 'member',
      tags: [],
      isActive: true,
      parentMid: '',
      createdAt: DateTime.now(),
    );

    final famData = <String, dynamic>{
      'familyDocId': 'fam_doc_1',
      'familyId': '723124',
      'yskFamilyId': '723124',
      'serialFamilyId': '08',
      'familyName': 'Lalji Family',
      'members': [memberWithSerial, memberWithYskId],
    };

    // Both members must yield the YSK Family ID 723124!
    expect(ExportField.familyId.getValue(famData, memberWithSerial), '723124');
    expect(ExportField.familyId.getValue(famData, memberWithYskId), '723124');
  });

  test('ExportField.familyId scans sibling members even if famData only had serial', () {
    final memberWithSerial1 = MemberModel(
      id: 'm1',
      mid: 'F-001-S01-101',
      familyDocId: 'fam_doc_1',
      subFamilyDocId: 'sub_doc_1',
      subFamilyId: '01',
      familyId: '08', // Serial
      familyName: 'Lalji Family',
      fullName: 'Member 1',
      surname: 'Patel',
      fatherName: '',
      motherName: '',
      gotra: '',
      gender: 'male',
      birthDate: '',
      education: '',
      bloodGroup: '',
      marriageStatus: '',
      nativeHome: '',
      phone: '',
      email: '',
      address: '',
      googleMapLink: '',
      surdhan: '',
      firms: [],
      whatsapp: '',
      instagram: '',
      facebook: '',
      photoUrl: '',
      password: '',
      role: 'member',
      tags: [],
      isActive: true,
      parentMid: '',
      createdAt: DateTime.now(),
    );

    final memberWithYskId = MemberModel(
      id: 'm7',
      mid: 'F-001-S01-107',
      familyDocId: 'fam_doc_1',
      subFamilyDocId: 'sub_doc_1',
      subFamilyId: '01',
      familyId: '723124', // Member 7 has the YSK ID
      familyName: 'Lalji Family',
      fullName: 'Member 7',
      surname: 'Patel',
      fatherName: '',
      motherName: '',
      gotra: '',
      gender: 'male',
      birthDate: '',
      education: '',
      bloodGroup: '',
      marriageStatus: '',
      nativeHome: '',
      phone: '',
      email: '',
      address: '',
      googleMapLink: '',
      surdhan: '',
      firms: [],
      whatsapp: '',
      instagram: '',
      facebook: '',
      photoUrl: '',
      password: '',
      role: 'member',
      tags: [],
      isActive: true,
      parentMid: '',
      createdAt: DateTime.now(),
    );

    // Notice famData only has '08' in familyId
    final famData = <String, dynamic>{
      'familyDocId': 'fam_doc_1',
      'familyId': '08',
      'serialFamilyId': '08',
      'familyName': 'Lalji Family',
      'members': [memberWithSerial1, memberWithYskId],
    };

    // Member 1 must automatically discover sibling Member 7's YSK ID 723124
    expect(ExportField.familyId.getValue(famData, memberWithSerial1), '723124');
    expect(ExportField.familyId.getValue(famData, memberWithYskId), '723124');
  });
}

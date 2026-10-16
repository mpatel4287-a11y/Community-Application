// test/common_elders_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_model.dart';
import 'package:comm_app/utils/member_sort_helper.dart';

void main() {
  group('Common Elders & Joint Family Sorting Tests', () {
    test('Common root parents (Father & Mother) lead the sort before sub-family heads and children', () {
      final father = MemberModel.empty().copyWith(
        id: 'father_1',
        mid: 'F-001-S00-101',
        fullName: 'Rameshbhai Patel',
        gender: 'male',
        relationToHead: 'head',
        isCommon: true,
        birthDate: '10/05/1950',
      );

      final mother = MemberModel.empty().copyWith(
        id: 'mother_1',
        mid: 'F-001-S00-102',
        fullName: 'Gitaben Patel',
        gender: 'female',
        relationToHead: 'wife',
        spouseMid: 'F-001-S00-101',
        isCommon: true,
        birthDate: '15/08/1954',
      );

      final elderSon = MemberModel.empty().copyWith(
        id: 'son_1',
        mid: 'F-001-S01-201',
        fullName: 'Amit Patel',
        gender: 'male',
        relationToHead: 'son',
        parentMid: 'F-001-S00-101',
        spouseMid: 'F-001-S01-202',
        birthDate: '20/01/1978',
      );

      final elderSonWife = MemberModel.empty().copyWith(
        id: 'son_1_wife',
        mid: 'F-001-S01-202',
        fullName: 'Priyakumari Patel',
        gender: 'female',
        relationToHead: 'daughter_in_law',
        spouseMid: 'F-001-S01-201',
        birthDate: '12/03/1980',
      );

      final youngerSon = MemberModel.empty().copyWith(
        id: 'son_2',
        mid: 'F-001-S02-301',
        fullName: 'Bhavin Patel',
        gender: 'male',
        relationToHead: 'son',
        parentMid: 'F-001-S00-101',
        spouseMid: 'F-001-S02-302',
        birthDate: '14/06/1982',
      );

      final youngerSonWife = MemberModel.empty().copyWith(
        id: 'son_2_wife',
        mid: 'F-001-S02-302',
        fullName: 'Kinjal Patel',
        gender: 'female',
        relationToHead: 'daughter_in_law',
        spouseMid: 'F-001-S02-301',
        birthDate: '01/09/1984',
      );

      final grandChild = MemberModel.empty().copyWith(
        id: 'grandchild_1',
        mid: 'F-001-S01-203',
        fullName: 'Aarav Patel',
        gender: 'male',
        relationToHead: 'grandson',
        parentMid: 'F-001-S01-201',
        birthDate: '05/05/2015',
        phone: '', // Child without mobile phone
      );

      // Pass in random shuffled order
      final members = [
        youngerSonWife,
        grandChild,
        elderSonWife,
        youngerSon,
        father,
        elderSon,
        mother,
      ];

      final sorted = MemberSortHelper.sortMembers(members);

      expect(sorted[0].id, equals('father_1')); // Common Father (Root Head)
      expect(sorted[1].id, equals('mother_1')); // Common Mother (Wife of Head)
      expect(sorted[2].id, equals('son_1'));    // Elder Son (Older child)
      expect(sorted[3].id, equals('son_1_wife'));// Elder Son's Spouse
      expect(sorted[4].id, equals('son_2'));    // Younger Son
      expect(sorted[5].id, equals('son_2_wife'));// Younger Son's Spouse
      expect(sorted[6].id, equals('grandchild_1')); // Grandchild (Minor)
    });

    test('MemberModel parses isCommon flag correctly from map', () {
      final data = {
        'fullName': 'Dahyabhai Patel',
        'isCommon': true,
        'phone': '',
        'birthDate': '12/12/1945',
      };
      final member = MemberModel.fromMap('mem_123', data);
      expect(member.isCommon, isTrue);
      expect(member.phone, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_model.dart';
import 'package:comm_app/utils/member_sort_helper.dart';

void main() {
  group('Older to Younger Sort Tests for PDF and Excel Export', () {
    test('sorts list of members strictly older to younger', () {
      final elderGrandfather = MemberModel.empty().copyWith(
        id: '1',
        fullName: 'Dhirubhai Patel',
        birthDate: '10/05/1945',
        relationToHead: 'Head',
      );

      final father = MemberModel.empty().copyWith(
        id: '2',
        fullName: 'Rameshbhai Patel',
        birthDate: '14/02/1972',
        relationToHead: 'Self',
      );

      final olderSon = MemberModel.empty().copyWith(
        id: '3',
        fullName: 'Ankit Patel',
        birthDate: '20/11/1998',
        relationToHead: 'Son',
      );

      final youngerSon = MemberModel.empty().copyWith(
        id: '4',
        fullName: 'Karan Patel',
        birthDate: '05/08/2003',
        relationToHead: 'Son',
      );

      final babyGrandson = MemberModel.empty().copyWith(
        id: '5',
        fullName: 'Aarav Patel',
        birthDate: '12/04/2021',
        relationToHead: 'Grandson',
      );

      // Pass in random order
      final List<MemberModel> unsorted = [olderSon, babyGrandson, father, youngerSon, elderGrandfather];
      final sorted = MemberSortHelper.sortOlderToYounger(unsorted);

      expect(sorted.map((m) => m.fullName).toList(), [
        'Dhirubhai Patel', // Born 1945
        'Rameshbhai Patel', // Born 1972
        'Ankit Patel',       // Born 1998
        'Karan Patel',       // Born 2003
        'Aarav Patel',       // Born 2021
      ]);
    });

    test('prioritizes deceased elder if birth date is equal or elder is marked late', () {
      final lateElder = MemberModel.empty().copyWith(
        id: '1',
        fullName: 'Late Harilal Patel',
        birthDate: '01/01/1938',
        isDeceased: true,
      );

      final livingGrandfather = MemberModel.empty().copyWith(
        id: '2',
        fullName: 'Mohanbhai Patel',
        birthDate: '01/01/1938',
        isDeceased: false,
      );

      final sorted = MemberSortHelper.sortOlderToYounger([livingGrandfather, lateElder]);
      expect(sorted.first.fullName, 'Late Harilal Patel');
    });
  });

  group('Snapchat ID Field Integration Tests', () {
    test('MemberModel properly serializes and deserializes snapchat field', () {
      final member = MemberModel.empty().copyWith(
        fullName: 'Jay Patel',
        snapchat: 'jaypatel_99',
      );

      final map = member.toMap();
      expect(map['snapchat'], 'jaypatel_99');

      final deserialized = MemberModel.fromMap('doc_123', map);
      expect(deserialized.snapchat, 'jaypatel_99');
      expect(deserialized.fullName, 'Jay Patel');
    });

    test('MemberModel handles missing or null snapchat field gracefully', () {
      final map = <String, dynamic>{
        'fullName': 'Priya Patel',
        'birthDate': '01/01/2000',
      };

      final deserialized = MemberModel.fromMap('doc_456', map);
      expect(deserialized.snapchat, '');
    });
  });
}

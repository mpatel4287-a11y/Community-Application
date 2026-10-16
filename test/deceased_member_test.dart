import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_model.dart';
import 'package:comm_app/models/person.dart';

void main() {
  group('Deceased / Late Member Tests', () {
    test('Default MemberModel has isDeceased false and isLate false', () {
      final member = MemberModel.empty();
      expect(member.isDeceased, isFalse);
      expect(member.tod, isEmpty);
      expect(member.isLate, isFalse);
    });

    test('Member marked as isDeceased true has isLate true', () {
      final member = MemberModel.empty().copyWith(
        fullName: 'Late Somabhai Patel',
        isDeceased: true,
      );
      expect(member.isDeceased, isTrue);
      expect(member.isLate, isTrue);
    });

    test('Member with tod non-empty has isLate true even if isDeceased boolean was omitted', () {
      final Map<String, dynamic> map = {
        'fullName': 'Late Kashiben Patel',
        'tod': '12/04/2018',
      };
      final member = MemberModel.fromMap('doc_123', map);
      expect(member.tod, '12/04/2018');
      expect(member.isLate, isTrue);
      expect(member.isDeceased, isTrue);
    });

    test('Serialization and Deserialization preserve isDeceased and tod', () {
      final original = MemberModel.empty().copyWith(
        id: 'mem_999',
        mid: 'F-001-S01-001',
        fullName: 'Late Tribhovandas Patel',
        phone: '', // Optional when deceased
        password: 'deceased',
        relationToHead: 'Grand Father',
        gender: 'Male',
        isDeceased: true,
        tod: '01/01/2010',
      );

      final map = original.toMap();
      expect(map['isDeceased'], isTrue);
      expect(map['tod'], '01/01/2010');

      final deserialized = MemberModel.fromMap('mem_999', map);
      expect(deserialized.id, 'mem_999');
      expect(deserialized.fullName, 'Late Tribhovandas Patel');
      expect(deserialized.isDeceased, isTrue);
      expect(deserialized.tod, '01/01/2010');
      expect(deserialized.isLate, isTrue);
    });

    test('Person model carries isDeceased and tod accurately', () {
      final person = Person(
        id: 'person_1',
        firstName: 'Somabhai',
        lastName: 'Patel',
        birthYear: 1940,
        gender: Gender.male,
        isDeceased: true,
        tod: '15/08/2015',
      );

      expect(person.isDeceased, isTrue);
      expect(person.tod, '15/08/2015');
    });

    test('copyWith updates isDeceased and tod cleanly', () {
      final m1 = MemberModel.empty().copyWith(fullName: 'Active Member');
      expect(m1.isLate, isFalse);

      final m2 = m1.copyWith(isDeceased: true, tod: '20/10/2021');
      expect(m2.isDeceased, isTrue);
      expect(m2.tod, '20/10/2021');
      expect(m2.isLate, isTrue);
    });
  });
}

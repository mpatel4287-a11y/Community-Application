import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/subfamily_model.dart';

void main() {
  group('SubFamily Order Number & Seniority Tests', () {
    test('Correctly parses integer orderNumber from data', () {
      final sf = SubFamilyModel.fromMap('sf1', {
        'subFamilyId': '01',
        'subFamilyName': 'Branch 1',
        'orderNumber': 1,
      });

      expect(sf.orderNumber, 1);
      expect(sf.isOlder, true);
      expect(sf.isYounger, false);
      expect(sf.seniorityDisplay, 'Order #1 (Oldest Branch)');
    });

    test('Correctly parses subsequent branches (2, 3...)', () {
      final sf2 = SubFamilyModel.fromMap('sf2', {
        'subFamilyId': '02',
        'subFamilyName': 'Branch 2',
        'orderNumber': 2,
      });

      expect(sf2.orderNumber, 2);
      expect(sf2.isOlder, false);
      expect(sf2.isYounger, true);
      expect(sf2.seniorityDisplay, 'Order #2 (Younger)');

      final sf3 = SubFamilyModel.fromMap('sf3', {
        'subFamilyId': '03',
        'subFamilyName': 'Branch 3',
        'orderNumber': 3,
      });

      expect(sf3.orderNumber, 3);
      expect(sf3.isYounger, true);
      expect(sf3.seniorityDisplay, 'Order #3 (Younger)');
    });

    test('Backward compatibility: parses legacy "older" and "younger" strings', () {
      final legacyOlder = SubFamilyModel.fromMap('sf_old', {
        'subFamilyId': '01',
        'subFamilyName': 'Old Branch',
        'seniority': 'older',
      });
      expect(legacyOlder.orderNumber, 1);
      expect(legacyOlder.isOlder, true);

      final legacyYounger = SubFamilyModel.fromMap('sf_young', {
        'subFamilyId': '02',
        'subFamilyName': 'Younger Branch',
        'seniority': 'younger',
      });
      expect(legacyYounger.orderNumber, 2);
      expect(legacyYounger.isYounger, true);
    });

    test('Sorts sub-families strictly by order number: 1 -> 2 -> 3', () {
      final sf3 = SubFamilyModel.fromMap('sf3', {'subFamilyId': '03', 'subFamilyName': 'Branch 3', 'orderNumber': 3});
      final sf1 = SubFamilyModel.fromMap('sf1', {'subFamilyId': '01', 'subFamilyName': 'Branch 1', 'orderNumber': 1});
      final sf2 = SubFamilyModel.fromMap('sf2', {'subFamilyId': '02', 'subFamilyName': 'Branch 2', 'orderNumber': 2});

      final list = [sf3, sf1, sf2];
      list.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

      expect(list.map((s) => s.orderNumber).toList(), [1, 2, 3]);
      expect(list.map((s) => s.subFamilyName).toList(), ['Branch 1', 'Branch 2', 'Branch 3']);
    });
  });
}

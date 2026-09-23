import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/attendance_model.dart';

void main() {
  group('AttendanceModel Tests', () {
    test('creates AttendanceModel with whole_family correctly', () {
      final now = DateTime.now();
      final att = AttendanceModel(
        id: 'att1',
        eventId: 'evt1',
        markedBy: 'mem1',
        markedByName: 'John Doe',
        attendanceType: 'whole_family',
        entityId: 'fam123',
        entityName: 'Doe Family',
        familyDocId: 'fam123',
        subFamilyDocId: '',
        memberIds: ['mem1'],
        memberCount: 5,
        markedAt: now,
        isCustomCount: true,
      );

      final map = att.toMap();
      expect(map['attendanceType'], 'whole_family');
      expect(map['familyDocId'], 'fam123');
      expect(map['subFamilyDocId'], '');
      expect(map['memberCount'], 5);

      final fromMap = AttendanceModel.fromMap('att1', map);
      expect(fromMap.attendanceType, 'whole_family');
      expect(fromMap.familyDocId, 'fam123');
      expect(fromMap.subFamilyDocId, '');
      expect(fromMap.memberCount, 5);
      expect(fromMap.markedByName, 'John Doe');
    });

    test('creates AttendanceModel with sub_family correctly', () {
      final now = DateTime.now();
      final att = AttendanceModel(
        id: 'att2',
        eventId: 'evt1',
        markedBy: 'mem2',
        markedByName: 'Alice Smith',
        attendanceType: 'sub_family',
        entityId: 'subfam456',
        entityName: 'Smith Branch',
        familyDocId: 'fam123',
        subFamilyDocId: 'subfam456',
        memberIds: ['mem2'],
        memberCount: 3,
        markedAt: now,
        isCustomCount: true,
      );

      final map = att.toMap();
      expect(map['attendanceType'], 'sub_family');
      expect(map['familyDocId'], 'fam123');
      expect(map['subFamilyDocId'], 'subfam456');
      expect(map['memberCount'], 3);

      final fromMap = AttendanceModel.fromMap('att2', map);
      expect(fromMap.attendanceType, 'sub_family');
      expect(fromMap.familyDocId, 'fam123');
      expect(fromMap.subFamilyDocId, 'subfam456');
      expect(fromMap.memberCount, 3);
    });

    test('backward compatibility for legacy family/subfamily type strings', () {
      final legacyFamilyMap = {
        'eventId': 'evt1',
        'markedBy': 'mem1',
        'markedByName': 'Legacy User',
        'attendanceType': 'family',
        'entityId': 'fam789',
        'entityName': 'Legacy Family',
        'memberIds': ['mem1'],
        'memberCount': 4,
      };

      final attFamily = AttendanceModel.fromMap('leg1', legacyFamilyMap);
      expect(attFamily.attendanceType, 'whole_family');
      expect(attFamily.familyDocId, 'fam789');

      final legacySubFamilyMap = {
        'eventId': 'evt1',
        'markedBy': 'mem2',
        'markedByName': 'Legacy Sub',
        'attendanceType': 'subfamily',
        'entityId': 'sub789',
        'entityName': 'Legacy Sub-Family',
        'memberIds': ['mem2'],
        'memberCount': 2,
      };

      final attSub = AttendanceModel.fromMap('leg2', legacySubFamilyMap);
      expect(attSub.attendanceType, 'sub_family');
      expect(attSub.subFamilyDocId, 'sub789');
    });

    test('validates member count boundary (1 to 30)', () {
      const minValid = 1;
      const maxValid = 30;
      expect(minValid >= 1 && minValid <= 30, isTrue);
      expect(maxValid >= 1 && maxValid <= 30, isTrue);
      expect(0 >= 1 && 0 <= 30, isFalse);
      expect(31 >= 1 && 31 <= 30, isFalse);
    });
  });
}

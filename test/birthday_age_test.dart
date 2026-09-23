import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/models/member_model.dart';
import 'package:intl/intl.dart';

void main() {
  group('MemberModel Birthday and Age Tests', () {
    test('Automatically calculates exact age from birth date', () {
      final now = DateTime.now();
      
      // Born exactly 20 years ago today
      final bdayToday = DateTime(now.year - 20, now.month, now.day);
      final bdayTodayStr = DateFormat('dd/MM/yyyy').format(bdayToday);
      expect(MemberModel.calculateAge(bdayTodayStr), 20);
      expect(MemberModel.isBirthdayTodayFromDate(bdayTodayStr), isTrue);

      // Birthday is tomorrow (has not happened yet this year) -> 19 years old
      final bdayTomorrow = now.add(const Duration(days: 1));
      final bdayTomorrowDate = DateTime(now.year - 20, bdayTomorrow.month, bdayTomorrow.day);
      final bdayTomorrowStr = DateFormat('dd/MM/yyyy').format(bdayTomorrowDate);
      expect(MemberModel.calculateAge(bdayTomorrowStr), 19);
      expect(MemberModel.isBirthdayTodayFromDate(bdayTomorrowStr), isFalse);

      // Birthday was yesterday (already occurred this year) -> 20 years old
      final bdayYesterday = now.subtract(const Duration(days: 1));
      final bdayYesterdayDate = DateTime(now.year - 20, bdayYesterday.month, bdayYesterday.day);
      final bdayYesterdayStr = DateFormat('dd/MM/yyyy').format(bdayYesterdayDate);
      expect(MemberModel.calculateAge(bdayYesterdayStr), 20);
      expect(MemberModel.isBirthdayTodayFromDate(bdayYesterdayStr), isFalse);
    });

    test('MemberModel constructor and fromMap auto-update age according to birthday', () {
      final now = DateTime.now();
      final bdayToday = DateTime(now.year - 25, now.month, now.day);
      final bdayTodayStr = DateFormat('dd/MM/yyyy').format(bdayToday);

      // Stale age passed in constructor (e.g. 15 years old stored years ago)
      final member = MemberModel.empty().copyWith(
        birthDate: bdayTodayStr,
      );

      // Must automatically reflect 25, not 0 or stale 15
      expect(member.age, 25);
      expect(member.isBirthdayToday, isTrue);

      // fromMap test with stale age in map data
      final fromMapMember = MemberModel.fromMap('doc123', {
        'fullName': 'Test Patel',
        'birthDate': bdayTodayStr,
        'age': 10, // outdated age from previous years
      });

      expect(fromMapMember.age, 25);
      expect(fromMapMember.isBirthdayToday, isTrue);
    });
  });
}

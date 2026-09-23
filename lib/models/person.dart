import 'member_model.dart';

class Person {
  final String id;
  final String firstName;
  final String lastName;
  final int birthYear;
  final Gender gender;
  final String? photoUrl;
  final String? details;
  final List<String> parentIds;
  final List<String> childrenIds;
  final int? age;
  final String? birthDate;
  final String? mid;
  final String? relationToHead;
  final String? spouseId;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.birthYear,
    required this.gender,
    this.photoUrl,
    this.details,
    this.parentIds = const [],
    this.childrenIds = const [],
    this.age,
    this.birthDate,
    this.mid,
    this.relationToHead,
    this.spouseId,
  });

  bool get isBirthdayToday => birthDate != null && birthDate!.isNotEmpty
      ? MemberModel.isBirthdayTodayFromDate(birthDate!)
      : false;

  String get fullName => '$firstName $lastName';
  String get initials {
    String res = '';
    if (firstName.isNotEmpty) res += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) res += lastName[0].toUpperCase();
    return res.isEmpty ? '?' : res;
  }

  String get birthYearString => 'b. $birthYear';
  int get calculatedAge {
    if (age != null) return age!;
    final now = DateTime.now();
    return now.year - birthYear;
  }
}

enum Gender { male, female }

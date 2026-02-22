// lib/models/member_model.dart

import 'dart:math';

class MemberModel {
  // Identity
  final String id;
  final String mid; // unique member ID (format: F{XX}-S{XX}-{XXX})
  final String familyDocId;
  final String subFamilyDocId; // Reference to sub-family document
  final String subFamilyId; // 2-digit sub-family ID (e.g., "01", "02")
  final String familyId; // 2-digit family prefix (e.g., "01", "02")
  final String familyName;

  // Personal
  final String fullName;
  final String surname;
  final String fatherName;
  final String motherName;
  final String gotra;
  final String gender; // male | female
  
  // Education
  final String education;

  final String birthDate; // dd/MM/yyyy
  final int age; // auto calculated
  final String bloodGroup;
  final String marriageStatus; // married | unmarried
  final String nativeHome;

  // Contact
  final String phone;
  final String email; // Added
  final String address;
  final String googleMapLink;
  final String surdhan; // Added

  // Firms (Multiple)
  final List<Map<String, String>> firms; // [{name, phone, mapLink}]

  // Social
  final String whatsapp;
  final String instagram;
  final String facebook;

  // Media
  final String photoUrl;
  final String password; // Added for member login

  // Meta
  final String role; // member | manager
  final List<String> tags; // admin only, max 15 chars
  final bool isActive;
  final String parentMid; // for family tree (parent member ID)
  final String relationToHead; // head | wife | daughter | son | daughter_in_law | grandson | grandsister | none
  final String subFamilyHeadRelationToMainHead; // for joint family linking
  final String tod; // Date of Death (dd/MM/yyyy)
  final DateTime createdAt;

  MemberModel({
    required this.id,
    required this.mid,
    required this.familyDocId,
    required this.subFamilyDocId,
    required this.subFamilyId,
    required this.familyId,
    required this.familyName,
    required this.fullName,
    required this.surname,
    required this.fatherName,
    required this.motherName,
    required this.gotra,
    required this.gender, // Added
    required this.birthDate,
    required this.age,
    required this.education, // Added
    required this.bloodGroup,
    required this.marriageStatus,
    required this.nativeHome,
    required this.phone,
    required this.email, // Added
    required this.address,
    required this.googleMapLink,
    required this.surdhan, // Added
    required this.firms,
    required this.whatsapp,
    required this.instagram,
    required this.facebook,
    required this.photoUrl,
    required this.password, // Added
    required this.role,
    required this.tags,
    required this.isActive,
    required this.parentMid,
    this.relationToHead = 'none',
    this.subFamilyHeadRelationToMainHead = '',
    this.tod = '',
    required this.createdAt,
  });

  static int calculateAge(String birthDateStr) {
    if (birthDateStr.isEmpty) return 0;
    try {
      final parts = birthDateStr.split('/');
      if (parts.length != 3) return 0;
      final birthDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  static String generateMid(String familyId, String subFamilyId) {
    // New Format: F-{FamilyHash}-S{SubFamilyId}-{Random}
    // Example: F-Q6R-S02-867
    
    // Deterministic 3-char family hash
    final familyHash = _generateFamilyHash(familyId);
    
    // Sub-family ID (ensure it's padded if needed, but usually is "01", etc.)
    final subPart = subFamilyId.padLeft(2, '0');
    
    // Truly random 3-digit part (100-999)
    final random = (100 + Random().nextInt(900)).toString();
    
    return 'F-$familyHash-S$subPart-$random';
  }

  static String _generateFamilyHash(String familyId) {
    // Normalize: trim and pad to 2 digits (e.g., "1" -> "01")
    // This ensures consistent hashes even if input formatting varies
    final normalizedId = familyId.trim().padLeft(2, '0');
    
    // Deterministic 3-char alphanumeric hash for the 2-digit familyId
    // Seeded with a salt to avoid direct predictability
    final input = 'FAM_PREFIX_$normalizedId';
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
        hash = (hash * 31 + input.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    // Convert to base 36 (alphanumeric) and take 3 chars
    String code = hash.toRadixString(36).toUpperCase();
    if (code.length < 3) {
      code = code.padLeft(3, '0');
    }
    return code.substring(code.length - 3);
  }

  // ---------------- TO MAP ----------------
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'mid': mid,
      'familyDocId': familyDocId,
      'subFamilyDocId': subFamilyDocId,
      'subFamilyId': subFamilyId,
      'familyId': familyId,
      'familyName': familyName,
      'fullName': fullName,
      'surname': surname,
      'fatherName': fatherName,
      'motherName': motherName,
      'gotra': gotra,
      'gender': gender,
      'birthDate': birthDate,
      'age': age,
      'education': education, // Added
      'bloodGroup': bloodGroup,
      'marriageStatus': marriageStatus,
      'nativeHome': nativeHome,
      'phone': phone,
      'email': email, // Added
      'address': address,
      'googleMapLink': googleMapLink,
      'surdhan': surdhan, // Added
      'whatsapp': whatsapp,
      'instagram': instagram,
      'facebook': facebook,
      'photoUrl': photoUrl,
      'password': password, // Added
      'role': role,
      'tags': tags,
      'isActive': isActive,
      'parentMid': parentMid,
      'relationToHead': relationToHead,
      'subFamilyHeadRelationToMainHead': subFamilyHeadRelationToMainHead,
      'tod': tod,
      'createdAt': createdAt,
    };

    if (firms.isNotEmpty) map['firms'] = firms;

    return map;
  }

  // ---------------- FROM MAP ----------------
  factory MemberModel.fromMap(String id, Map<String, dynamic> data) {
    return MemberModel(
      id: id,
      mid: data['mid'] ?? '',
      familyDocId: data['familyDocId'] ?? '',
      subFamilyDocId: data['subFamilyDocId'] ?? '',
      subFamilyId: data['subFamilyId'] ?? '',
      familyId: data['familyId'] ?? '',
      familyName: data['familyName'] ?? '',
      fullName: data['fullName'] ?? '',
      surname: data['surname'] ?? '',
      fatherName: data['fatherName'] ?? '',
      motherName: data['motherName'] ?? '',
      gotra: data['gotra'] ?? '',
      gender: data['gender'] ?? 'male',
      birthDate: data['birthDate'] ?? '',
      age: data['age'] ?? 0,
      education: data['education'] ?? '', // Added
      bloodGroup: data['bloodGroup'] ?? '',
      marriageStatus: data['marriageStatus'] ?? 'unmarried',
      nativeHome: data['nativeHome'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '', // Added
      address: data['address'] ?? '',
      googleMapLink: data['googleMapLink'] ?? '',
      surdhan: data['surdhan'] ?? '', // Added
      firms: (data['firms'] as List<dynamic>? ?? [])
          .map((e) => Map<String, String>.from(e))
          .toList(),
      whatsapp: data['whatsapp'] ?? '',
      instagram: data['instagram'] ?? '',
      facebook: data['facebook'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      password: data['password'] ?? '123456', // Added default for existing
      role: data['role'] ?? 'member',
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['isActive'] ?? true,
      parentMid: data['parentMid'] ?? '',
      relationToHead: data['relationToHead'] ?? 'none',
      subFamilyHeadRelationToMainHead: data['subFamilyHeadRelationToMainHead'] ?? '',
      tod: data['tod'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // ---------------- COPY WITH ----------------
  MemberModel copyWith({
    String? id,
    String? mid,
    String? familyDocId,
    String? subFamilyDocId,
    String? subFamilyId,
    String? familyId,
    String? familyName,
    String? fullName,
    String? surname,
    String? fatherName,
    String? motherName,
    String? gotra,
    String? gender,
    String? birthDate,
    String? education,
    String? bloodGroup,
    String? marriageStatus,
    String? nativeHome,
    String? phone,
    String? email, // Added
    String? address,
    String? googleMapLink,
    String? surdhan, // Added
    List<Map<String, String>>? firms,
    String? whatsapp,
    String? instagram,
    String? facebook,
    String? photoUrl,
    String? password, // Added
    String? role,
    List<String>? tags,
    bool? isActive,
    String? parentMid,
    String? relationToHead,
    String? subFamilyHeadRelationToMainHead,
    String? tod,
  }) {
    return MemberModel(
      id: id ?? this.id,
      mid: mid ?? this.mid,
      familyDocId: familyDocId ?? this.familyDocId,
      subFamilyDocId: subFamilyDocId ?? this.subFamilyDocId,
      subFamilyId: subFamilyId ?? this.subFamilyId,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      fullName: fullName ?? this.fullName,
      surname: surname ?? this.surname,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      gotra: gotra ?? this.gotra,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      age: birthDate != null ? MemberModel.calculateAge(birthDate) : age,
      education: education ?? this.education, // Added
      bloodGroup: bloodGroup ?? this.bloodGroup,
      marriageStatus: marriageStatus ?? this.marriageStatus,
      nativeHome: nativeHome ?? this.nativeHome,
      phone: phone ?? this.phone,
      email: email ?? this.email, // Added
      address: address ?? this.address,
      googleMapLink: googleMapLink ?? this.googleMapLink,
      surdhan: surdhan ?? this.surdhan, // Added
      firms: firms ?? this.firms,
      whatsapp: whatsapp ?? this.whatsapp,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      photoUrl: photoUrl ?? this.photoUrl,
      password: password ?? this.password, // Added
      role: role ?? this.role,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      parentMid: parentMid ?? this.parentMid,
      relationToHead: relationToHead ?? this.relationToHead,
      subFamilyHeadRelationToMainHead: subFamilyHeadRelationToMainHead ?? this.subFamilyHeadRelationToMainHead,
      tod: tod ?? this.tod,
      createdAt: createdAt,
    );
  }

  static MemberModel empty() {
    return MemberModel(
      id: '',
      mid: '',
      familyDocId: '',
      subFamilyDocId: '',
      subFamilyId: '',
      familyId: '',
      familyName: '',
      fullName: '',
      surname: '',
      fatherName: '',
      motherName: '',
      gotra: '',
      gender: 'male',
      birthDate: '',
      age: 0,
      education: '',
      bloodGroup: '',
      marriageStatus: 'unmarried',
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
      relationToHead: 'none',
      subFamilyHeadRelationToMainHead: '',
      tod: '',
      createdAt: DateTime.now(),
    );
  }
}

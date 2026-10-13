import 'package:cloud_firestore/cloud_firestore.dart';

class SubFamilyModel {
  final String id;
  final String subFamilyId; // 2-digit sub family ID (01, 02, 03, ...)
  final String mainFamilyDocId;
  final String mainFamilyId;
  final String mainFamilyName;
  final String subFamilyName;
  final String headOfFamily;
  final String description;
  final int memberCount;
  final bool isActive;
  final String seniority; // 'older' | 'younger' | ''
  final DateTime createdAt;
  final DateTime? updatedAt;

  SubFamilyModel({
    required this.id,
    required this.subFamilyId,
    required this.mainFamilyDocId,
    required this.mainFamilyId,
    required this.mainFamilyName,
    required this.subFamilyName,
    required this.headOfFamily,
    this.description = '',
    this.memberCount = 0,
    this.isActive = true,
    this.seniority = '',
    required this.createdAt,
    this.updatedAt,
  });

  bool get isOlder => seniority.toLowerCase() == 'older';
  bool get isYounger => seniority.toLowerCase() == 'younger';
  String get seniorityDisplay {
    if (isOlder) return 'Elder Sub-Family';
    if (isYounger) return 'Younger Sub-Family';
    return '';
  }

  // Create SubFamily from Firestore document
  factory SubFamilyModel.fromMap(String id, Map<String, dynamic> data) {
    return SubFamilyModel(
      id: id,
      subFamilyId: data['subFamilyId'] ?? '',
      mainFamilyDocId: data['mainFamilyDocId'] ?? '',
      mainFamilyId: data['mainFamilyId'] ?? '',
      mainFamilyName: data['mainFamilyName'] ?? '',
      subFamilyName: data['subFamilyName'] ?? '',
      headOfFamily: data['headOfFamily'] ?? '',
      description: data['description'] ?? '',
      memberCount: data['memberCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      seniority: data['seniority'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert SubFamily to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'subFamilyId': subFamilyId,
      'mainFamilyDocId': mainFamilyDocId,
      'mainFamilyId': mainFamilyId,
      'mainFamilyName': mainFamilyName,
      'subFamilyName': subFamilyName,
      'headOfFamily': headOfFamily,
      'description': description,
      'memberCount': memberCount,
      'isActive': isActive,
      'seniority': seniority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create copy with updated fields
  SubFamilyModel copyWith({
    String? id,
    String? subFamilyId,
    String? mainFamilyDocId,
    String? mainFamilyId,
    String? mainFamilyName,
    String? subFamilyName,
    String? headOfFamily,
    String? description,
    int? memberCount,
    bool? isActive,
    String? seniority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubFamilyModel(
      id: id ?? this.id,
      subFamilyId: subFamilyId ?? this.subFamilyId,
      mainFamilyDocId: mainFamilyDocId ?? this.mainFamilyDocId,
      mainFamilyId: mainFamilyId ?? this.mainFamilyId,
      mainFamilyName: mainFamilyName ?? this.mainFamilyName,
      subFamilyName: subFamilyName ?? this.subFamilyName,
      headOfFamily: headOfFamily ?? this.headOfFamily,
      description: description ?? this.description,
      memberCount: memberCount ?? this.memberCount,
      isActive: isActive ?? this.isActive,
      seniority: seniority ?? this.seniority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SubFamilyModel(id: $id, subFamilyId: $subFamilyId, subFamilyName: $subFamilyName, headOfFamily: $headOfFamily, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubFamilyModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

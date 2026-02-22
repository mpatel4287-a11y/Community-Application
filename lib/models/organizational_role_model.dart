// lib/models/organizational_role_model.dart


class OrganizationalRoleModel {
  final String id;
  final String category; // e.g., 'Samaj', 'Yuvak Mandal', 'Mahila Mandal'
  final String roleTitle; // e.g., 'President', 'Secretary'
  final List<String> memberMids; // List of member MIDs (3-digit IDs) assigned to this role
  final int order; // For display sorting
  final DateTime createdAt;

  OrganizationalRoleModel({
    required this.id,
    required this.category,
    required this.roleTitle,
    this.memberMids = const [],
    this.order = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'roleTitle': roleTitle,
      'memberMids': memberMids,
      'order': order,
      'createdAt': createdAt,
    };
  }

  factory OrganizationalRoleModel.fromMap(String id, Map<String, dynamic> data) {
    return OrganizationalRoleModel(
      id: id,
      category: data['category'] ?? '',
      roleTitle: data['roleTitle'] ?? '',
      memberMids: List<String>.from(data['memberMids'] ?? []),
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  OrganizationalRoleModel copyWith({
    String? category,
    String? roleTitle,
    List<String>? memberMids,
    int? order,
  }) {
    return OrganizationalRoleModel(
      id: id,
      category: category ?? this.category,
      roleTitle: roleTitle ?? this.roleTitle,
      memberMids: memberMids ?? this.memberMids,
      order: order ?? this.order,
      createdAt: createdAt,
    );
  }
}

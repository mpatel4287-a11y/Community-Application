// lib/models/firm_model.dart

class FirmModel {
  final String id;
  final String name;
  final DateTime createdAt;

  FirmModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  // ---------------- TO MAP ----------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
    };
  }

  // ---------------- FROM MAP ----------------
  factory FirmModel.fromMap(String id, Map<String, dynamic> data) {
    return FirmModel(
      id: id,
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // ---------------- COPY WITH ----------------
  FirmModel copyWith({
    String? name,
  }) {
    return FirmModel(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }
}

// lib/models/sub_firm_model.dart

class SubFirmModel {
  final String id;
  final String firmId;
  final String name;
  final String location;
  final String contactNumber;
  final String contactName;
  final DateTime createdAt;

  SubFirmModel({
    required this.id,
    required this.firmId,
    required this.name,
    required this.location,
    required this.contactNumber,
    required this.contactName,
    required this.createdAt,
  });

  // ---------------- TO MAP ----------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firmId': firmId,
      'name': name,
      'location': location,
      'contactNumber': contactNumber,
      'contactName': contactName,
      'createdAt': createdAt,
    };
  }

  // ---------------- FROM MAP ----------------
  factory SubFirmModel.fromMap(String id, Map<String, dynamic> data) {
    return SubFirmModel(
      id: id,
      firmId: data['firmId'] ?? '',
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      contactName: data['contactName'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // ---------------- COPY WITH ----------------
  SubFirmModel copyWith({
    String? firmId,
    String? name,
    String? location,
    String? contactNumber,
    String? contactName,
  }) {
    return SubFirmModel(
      id: id,
      firmId: firmId ?? this.firmId,
      name: name ?? this.name,
      location: location ?? this.location,
      contactNumber: contactNumber ?? this.contactNumber,
      contactName: contactName ?? this.contactName,
      createdAt: createdAt,
    );
  }
}

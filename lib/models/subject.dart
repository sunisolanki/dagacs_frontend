/// Matches backend `SubjectDTO`.
///
/// IMPORTANT: Subject is a FLAT backend entity - it has no parent FK, and
/// `department` is a plain String. The Dart model preserves the backend shape
/// exactly and does NOT invent any relationship fields.
class Subject {
  final int? id;
  final String? code;
  final String? name;
  final String? description;
  final String? creditHours;
  final String? department;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  const Subject({
    this.id,
    this.code,
    this.name,
    this.description,
    this.creditHours,
    this.department,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int?,
      code: json['code'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      creditHours: json['creditHours'] as String?,
      department: json['department'] as String?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Mutable fields sent for POST/PUT `/api/admin/subjects`.
class SubjectRequest {
  const SubjectRequest({
    required this.code,
    required this.name,
    required this.creditHours,
    required this.status,
    this.description,
    this.department,
  });

  final String code;
  final String name;
  final String creditHours;
  final String status;
  final String? description;
  final String? department;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'creditHours': creditHours,
        'status': status,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (department != null && department!.isNotEmpty)
          'department': department,
      };
}

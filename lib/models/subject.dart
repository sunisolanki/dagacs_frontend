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

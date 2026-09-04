/// Matches backend `DepartmentDTO`.
class Department {
  final int? id;
  final String? name;
  final String? code;
  final String? description;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;

  const Department({
    this.id,
    this.name,
    this.code,
    this.description,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as int?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

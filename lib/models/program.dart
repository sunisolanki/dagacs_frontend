import 'department.dart';

/// Matches backend `ProgramDTO`.
class Program {
  final int? id;
  final String? name;
  final String? code;
  final String? duration;
  final String? description;
  final Department? department;
  final int? departmentId;
  final String? createdAt;
  final String? updatedAt;

  const Program({
    this.id,
    this.name,
    this.code,
    this.duration,
    this.description,
    this.department,
    this.departmentId,
    this.createdAt,
    this.updatedAt,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    final deptJson = json['department'];
    return Program(
      id: json['id'] as int?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      duration: json['duration'] as String?,
      description: json['description'] as String?,
      department: deptJson is Map<String, dynamic>
          ? Department.fromJson(deptJson)
          : null,
      departmentId: json['departmentId'] as int?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

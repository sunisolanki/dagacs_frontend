import 'department.dart';

/// Matches backend `SubjectDTO`.
///
/// Subject now carries a real Department relationship (`departmentId` plus the
/// nested `department` object). The legacy free-text `department` String is not
/// part of the API anymore.
class Subject {
  final int? id;
  final String? code;
  final String? name;
  final String? description;
  final String? creditHours;
  final int? departmentId;
  final Department? department;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  const Subject({
    this.id,
    this.code,
    this.name,
    this.description,
    this.creditHours,
    this.departmentId,
    this.department,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    final deptJson = json['department'];
    return Subject(
      id: json['id'] as int?,
      code: json['code'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      creditHours: json['creditHours'] as String?,
      departmentId: json['departmentId'] as int?,
      department: deptJson is Map<String, dynamic>
          ? Department.fromJson(deptJson)
          : null,
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
    required this.departmentId,
    required this.status,
    this.description,
  });

  final String code;
  final String name;
  final String creditHours;
  final int departmentId;
  final String status;
  final String? description;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'creditHours': creditHours,
        'departmentId': departmentId,
        'status': status,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
/// Matches backend `TeacherDTO` (M9.3).
///
/// Represents an existing `Teacher` row surfaced by `GET /api/admin/teachers`.
/// The frontend only reads these rows for the assignment form dropdowns; it
/// never provisions or mutates teachers (no teacher create/update API exists by
/// design).
class Teacher {
  final int? id;
  final String? email;
  final String? fullName;
  final String? designation;
  final String? status;
  final int? departmentId;
  final String? departmentName;

  const Teacher({
    this.id,
    this.email,
    this.fullName,
    this.designation,
    this.status,
    this.departmentId,
    this.departmentName,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
        id: json['id'] as int?,
        email: json['email'] as String?,
        fullName: json['fullName'] as String?,
        designation: json['designation'] as String?,
        status: json['status'] as String?,
        departmentId: json['departmentId'] as int?,
        departmentName: json['departmentName'] as String?,
      );
}
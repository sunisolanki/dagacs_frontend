/// Matches backend `StudentDTO` (AttendanceSessionService.getStudentsForSession response).
class SessionStudent {
  final int? id;
  final String? rollNumber;
  final String? name;
  final String? enrollmentNumber;

  const SessionStudent({
    this.id,
    this.rollNumber,
    this.name,
    this.enrollmentNumber,
  });

  factory SessionStudent.fromJson(Map<String, dynamic> json) {
    return SessionStudent(
      id: json['id'] as int?,
      rollNumber: json['rollNumber'] as String?,
      name: json['name'] as String?,
      enrollmentNumber: json['enrollmentNumber'] as String?,
    );
  }
}

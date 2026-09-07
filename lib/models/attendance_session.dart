/// Matches backend `AttendanceSessionDTO` (AttendanceController response).
class AttendanceSession {
  final int? id;
  final int? subjectId;
  final String? subjectName;
  final int? sectionId;
  final String? sectionName;
  final int? teacherId;
  final String? lecturePeriod;
  final String? date;
  final String? status;
  final String? createdAt;

  const AttendanceSession({
    this.id,
    this.subjectId,
    this.subjectName,
    this.sectionId,
    this.sectionName,
    this.teacherId,
    this.lecturePeriod,
    this.date,
    this.status,
    this.createdAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as int?,
      subjectId: json['subjectId'] as int?,
      subjectName: json['subjectName'] as String?,
      sectionId: json['sectionId'] as int?,
      sectionName: json['sectionName'] as String?,
      teacherId: json['teacherId'] as int?,
      lecturePeriod: json['lecturePeriod'] as String?,
      date: json['date'] as String?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

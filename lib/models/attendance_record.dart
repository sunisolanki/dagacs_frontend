/// Matches backend `AttendanceRecordDTO` (AttendanceService / StudentAttendanceService response).
class AttendanceRecord {
  final int? id;
  final int? studentId;
  final int? subjectId;
  final int? sectionId;
  final String? status;
  final String? lecturePeriod;
  final String? date;
  final bool? isPresent;
  final int? sessionId;
  final int? markedById;
  final String? markedByName;
  final String? createdAt;

  const AttendanceRecord({
    this.id,
    this.studentId,
    this.subjectId,
    this.sectionId,
    this.status,
    this.lecturePeriod,
    this.date,
    this.isPresent,
    this.sessionId,
    this.markedById,
    this.markedByName,
    this.createdAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int?,
      studentId: json['studentId'] as int?,
      subjectId: json['subjectId'] as int?,
      sectionId: json['sectionId'] as int?,
      status: json['status'] as String?,
      lecturePeriod: json['lecturePeriod'] as String?,
      date: json['date'] as String?,
      isPresent: json['isPresent'] as bool?,
      sessionId: json['sessionId'] as int?,
      markedById: json['markedById'] as int?,
      markedByName: json['markedByName'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

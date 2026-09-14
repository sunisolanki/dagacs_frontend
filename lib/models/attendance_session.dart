/// Matches backend `AttendanceSessionDTO` (AttendanceController response).
///
/// Exactly one of [sectionId] | [batchId] is set (XOR). sectionName is present
/// for section-mode sessions; batchName for batch-mode (zero-section batches).
class AttendanceSession {
  final int? id;
  final int? subjectId;
  final String? subjectName;
  final int? sectionId;
  final String? sectionName;
  final int? batchId;
  final String? batchName;
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
    this.batchId,
    this.batchName,
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
      batchId: json['batchId'] as int?,
      batchName: json['batchName'] as String?,
      teacherId: json['teacherId'] as int?,
      lecturePeriod: json['lecturePeriod'] as String?,
      date: json['date'] as String?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
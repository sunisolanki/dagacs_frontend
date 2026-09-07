/// Matches the backend `HodAuditLogEntryDTO`.
///
/// Read-only correction history for the HOD's department. No internal entity
/// IDs are exposed by the backend. [updatedAt] is a backend serialized
/// timestamp string; Flutter renders it textually and never interprets it.
class HodAuditLogEntry {
  final String? studentName;
  final String? rollNo;
  final String? subjectName;
  final String? sectionName;
  final String? date;
  final String? previousStatus;
  final String? newStatus;
  final String? updatedBy;
  final String? updatedAt;
  final String? reason;

  const HodAuditLogEntry({
    this.studentName,
    this.rollNo,
    this.subjectName,
    this.sectionName,
    this.date,
    this.previousStatus,
    this.newStatus,
    this.updatedBy,
    this.updatedAt,
    this.reason,
  });

  factory HodAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return HodAuditLogEntry(
      studentName: json['studentName'] as String?,
      rollNo: json['rollNo'] as String?,
      subjectName: json['subjectName'] as String?,
      sectionName: json['sectionName'] as String?,
      date: json['date'] as String?,
      previousStatus: json['previousStatus'] as String?,
      newStatus: json['newStatus'] as String?,
      updatedBy: json['updatedBy'] as String?,
      updatedAt: json['updatedAt'] as String?,
      reason: json['reason'] as String?,
    );
  }
}
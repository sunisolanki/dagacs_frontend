/// Matches backend `TeacherAssignmentDTO` (M9.3).
///
/// Carries the request identities (teacherId / subjectOfferingId / sectionId |
/// batchId) plus the fully derived display context. All academic context
/// (Subject, Semester, AcademicSession, Program, Department, Batch) is computed
/// server-side — the client never sends context ids.
class TeacherAssignment {
  final int? id;
  final int? teacherId;
  final String? teacherName;
  final String? teacherEmail;
  final int? subjectOfferingId;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final int? semesterId;
  final String? semesterName;
  final int? sessionId;
  final String? sessionName;
  final int? programId;
  final String? programName;
  final int? departmentId;
  final String? departmentName;
  final int? sectionId;
  final String? sectionCode;
  final String? sectionName;
  final int? batchId;
  final String? batchCode;
  final String? createdAt;
  final String? updatedAt;

  const TeacherAssignment({
    this.id,
    this.teacherId,
    this.teacherName,
    this.teacherEmail,
    this.subjectOfferingId,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.semesterId,
    this.semesterName,
    this.sessionId,
    this.sessionName,
    this.programId,
    this.programName,
    this.departmentId,
    this.departmentName,
    this.sectionId,
    this.sectionCode,
    this.sectionName,
    this.batchId,
    this.batchCode,
    this.createdAt,
    this.updatedAt,
  });

  factory TeacherAssignment.fromJson(Map<String, dynamic> json) =>
      TeacherAssignment(
        id: json['id'] as int?,
        teacherId: json['teacherId'] as int?,
        teacherName: json['teacherName'] as String?,
        teacherEmail: json['teacherEmail'] as String?,
        subjectOfferingId: json['subjectOfferingId'] as int?,
        subjectId: json['subjectId'] as int?,
        subjectCode: json['subjectCode'] as String?,
        subjectName: json['subjectName'] as String?,
        semesterId: json['semesterId'] as int?,
        semesterName: json['semesterName'] as String?,
        sessionId: json['sessionId'] as int?,
        sessionName: json['sessionName'] as String?,
        programId: json['programId'] as int?,
        programName: json['programName'] as String?,
        departmentId: json['departmentId'] as int?,
        departmentName: json['departmentName'] as String?,
        sectionId: json['sectionId'] as int?,
        sectionCode: json['sectionCode'] as String?,
        sectionName: json['sectionName'] as String?,
        batchId: json['batchId'] as int?,
        batchCode: json['batchCode'] as String?,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}

/// Mutable fields sent for POST/PUT `/api/admin/teacher-assignments`.
///
/// The request contract carries {teacherId, subjectOfferingId} plus exactly one
/// of {sectionId | batchId} (XOR). Context ids (subjectId / semesterId /
/// academicSessionId / programId / departmentId / studentId) are deliberately
/// absent and always derived server-side.
class TeacherAssignmentRequest {
  const TeacherAssignmentRequest({
    required this.teacherId,
    required this.subjectOfferingId,
    this.sectionId,
    this.batchId,
  });

  final int teacherId;
  final int subjectOfferingId;
  final int? sectionId;
  final int? batchId;

  Map<String, dynamic> toJson() => {
        'teacherId': teacherId,
        'subjectOfferingId': subjectOfferingId,
        if (sectionId != null) 'sectionId': sectionId,
        if (batchId != null) 'batchId': batchId,
      };
}
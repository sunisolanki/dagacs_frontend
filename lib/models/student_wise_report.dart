/// Models the additive student-wise attendance matrix
/// (`TeacherStudentWiseReportService`/`GET /api/teacher/attendance/student-wise`).
///
/// One row per student (enrollment-ordered), one column per distinct
/// (date, lecturePeriod) session; cells stay keyed to exactly one session so
/// same-date sessions are never collapsed.
library;

class StudentWiseReport {
  final int? subjectId;
  final String? subjectName;
  final int? sectionId;
  final String? sectionName;
  final int? batchId;
  final String? batchCode;
  final List<StudentWiseColumn> columns;
  final List<StudentWiseRow> rows;

  const StudentWiseReport({
    this.subjectId,
    this.subjectName,
    this.sectionId,
    this.sectionName,
    this.batchId,
    this.batchCode,
    required this.columns,
    required this.rows,
  });

  factory StudentWiseReport.fromJson(Map<String, dynamic> json) {
    return StudentWiseReport(
      subjectId: json['subjectId'] as int?,
      subjectName: json['subjectName'] as String?,
      sectionId: json['sectionId'] as int?,
      sectionName: json['sectionName'] as String?,
      batchId: json['batchId'] as int?,
      batchCode: json['batchCode'] as String?,
      columns: (json['columns'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => StudentWiseColumn.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rows: (json['rows'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => StudentWiseRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class StudentWiseColumn {
  final int sessionId;
  final String date;
  final String lecturePeriod;

  const StudentWiseColumn({
    required this.sessionId,
    required this.date,
    required this.lecturePeriod,
  });

  factory StudentWiseColumn.fromJson(Map<String, dynamic> json) =>
      StudentWiseColumn(
        sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
        date: json['date'] as String? ?? '',
        lecturePeriod: json['lecturePeriod'] as String? ?? '',
      );
}

class StudentWiseRow {
  final int? studentId;
  final String? rollNumber;
  final String? enrollmentNumber;
  final String? name;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;
  final List<StudentWiseCell> cells;

  const StudentWiseRow({
    this.studentId,
    this.rollNumber,
    this.enrollmentNumber,
    this.name,
    this.presentCount = 0,
    this.totalRecordedCount = 0,
    this.percentage,
    required this.cells,
  });

  factory StudentWiseRow.fromJson(Map<String, dynamic> json) =>
      StudentWiseRow(
        studentId: (json['studentId'] as num?)?.toInt(),
        rollNumber: json['rollNumber'] as String?,
        enrollmentNumber: json['enrollmentNumber'] as String?,
        name: json['name'] as String?,
        presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
        totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
        cells: (json['cells'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => StudentWiseCell.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  String? cellStatus(int sessionId) {
    for (final cell in cells) {
      if (cell.sessionId == sessionId) return cell.status;
    }
    return null;
  }
}

class StudentWiseCell {
  final int sessionId;
  final String status;
  final bool isPresent;

  const StudentWiseCell({
    required this.sessionId,
    required this.status,
    required this.isPresent,
  });

  factory StudentWiseCell.fromJson(Map<String, dynamic> json) =>
      StudentWiseCell(
        sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        isPresent: json['isPresent'] as bool? ?? false,
      );
}
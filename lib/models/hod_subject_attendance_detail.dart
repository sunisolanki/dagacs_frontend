import 'package:flutter/foundation.dart';

import 'hod_attendance_context.dart';

/// One student row of the subject attendance detail.
@immutable
class HodSubjectAttendanceStudentRow {
  const HodSubjectAttendanceStudentRow({
    required this.studentId,
    required this.enrollmentNumber,
    required this.rollNumber,
    required this.studentName,
    required this.present,
    required this.total,
    this.percentage,
  });

  factory HodSubjectAttendanceStudentRow.fromJson(Map<String, dynamic> json) =>
      HodSubjectAttendanceStudentRow(
        studentId: (json['studentId'] as num?)?.toInt() ?? 0,
        enrollmentNumber: json['enrollmentNumber'] as String? ?? '',
        rollNumber: json['rollNumber'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        present: (json['present'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
      );

  final int studentId;
  final String enrollmentNumber;
  final String rollNumber;
  final String studentName;
  final int present;

  /// The denominator for this student in this subject: the <b>conducted
  /// classes</b> of the subject, identical for every student of the class.
  final int total;

  /// Null only when the subject has no conducted class at all.
  final double? percentage;

  String get identity => enrollmentNumber.isNotEmpty ? enrollmentNumber : rollNumber;

  /// True when the subject had a class, so a real percentage exists.
  bool get hasConductedClass => total > 0;
}

/// Attendance detail for one subject inside the currently selected HOD academic
/// context.
///
/// [studentRows] is the enrolled population of the context, not only the
/// students who happen to have marks, so a student with no records in this
/// subject is still listed — against the subject's conducted classes, never as a
/// meaningless `0 / 0`.
@immutable
class HodSubjectAttendanceDetail {
  const HodSubjectAttendanceDetail({
    required this.context,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.programName,
    required this.semesterName,
    required this.sectionName,
    required this.facultyNames,
    required this.totalClasses,
    required this.students,
    required this.presentCount,
    required this.totalClassesAcrossStudents,
    this.averageAttendance,
    required this.studentsBelowThreshold,
    this.thresholdPercentage,
    this.studentRows = const [],
  });

  factory HodSubjectAttendanceDetail.fromJson(Map<String, dynamic> json) =>
      HodSubjectAttendanceDetail(
        context: json['context'] is Map
            ? HodAttendanceContext.fromJson(
                Map<String, dynamic>.from(json['context'] as Map))
            : HodAttendanceContext.empty,
        subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        programName: json['programName'] as String?,
        semesterName: json['semesterName'] as String?,
        sectionName: json['sectionName'] as String?,
        facultyNames: (json['facultyNames'] as List?)
                ?.where((e) => e != null)
                .map((e) => e.toString())
                .toList(growable: false) ??
            const [],
        totalClasses: (json['totalClasses'] as num?)?.toInt() ?? 0,
        students: (json['students'] as num?)?.toInt() ?? 0,
        presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
        totalClassesAcrossStudents:
            (json['totalClassesAcrossStudents'] as num?)?.toInt() ?? 0,
        averageAttendance: (json['averageAttendance'] as num?)?.toDouble(),
        studentsBelowThreshold:
            (json['studentsBelowThreshold'] as num?)?.toInt() ?? 0,
        thresholdPercentage: (json['thresholdPercentage'] as num?)?.toDouble(),
        studentRows: (json['studentRows'] as List?)
                ?.whereType<Map>()
                .map((e) => HodSubjectAttendanceStudentRow.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
      );

  final HodAttendanceContext context;
  final int subjectId;
  final String subjectCode;
  final String subjectName;
  final String? programName;
  final String? semesterName;
  final String? sectionName;

  /// Real teaching assignments; empty when no teacher is assigned yet. Never
  /// invented by the client.
  final List<String> facultyNames;

  /// <b>Conducted classes</b> of this subject in the context, never attendance
  /// records. Null when the subject is not scoped to a section.
  final int totalClasses;

  /// Enrolled students of the context, including those with no marks.
  final int students;

  final int presentCount;

  /// The denominator behind [averageAttendance]: [totalClasses] measured against
  /// [students]. Every enrolled student is measured against every conducted
  /// class, so an unmarked class stays in the denominator.
  final int totalClassesAcrossStudents;

  /// [presentCount] / [totalClassesAcrossStudents], or null at zero.
  final double? averageAttendance;

  final int studentsBelowThreshold;
  final double? thresholdPercentage;
  final List<HodSubjectAttendanceStudentRow> studentRows;

  String get label => subjectCode.isNotEmpty ? subjectCode : subjectName;

  String get facultyLabel =>
      facultyNames.isEmpty ? 'No faculty assigned' : facultyNames.join(', ');

  bool get hasConductedClasses => totalClasses > 0;
}

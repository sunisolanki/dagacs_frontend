import 'package:flutter/foundation.dart';

import 'hod_attendance_context.dart';

/// One subject line of the HOD student attendance detail.
@immutable
class HodStudentSubjectAttendance {
  const HodStudentSubjectAttendance({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.classes,
    required this.present,
    required this.notAttended,
    this.percentage,
  });

  factory HodStudentSubjectAttendance.fromJson(Map<String, dynamic> json) =>
      HodStudentSubjectAttendance(
        subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        classes: (json['classes'] as num?)?.toInt() ?? 0,
        present: (json['present'] as num?)?.toInt() ?? 0,
        notAttended: (json['notAttended'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
      );

  final int subjectId;
  final String subjectCode;
  final String subjectName;

  /// The denominator: <b>conducted classes</b> of this subject, identical for
  /// every student of the class. An unmarked class stays inside it, so a student
  /// who was never marked reports `0 / 40 = 0%` instead of disappearing.
  final int classes;
  final int present;

  /// Conducted classes this student did not attend: explicitly ABSENT marks plus
  /// every unmarked conducted class.
  final int notAttended;

  /// Null only when the subject had no conducted class at all.
  final double? percentage;

  bool get hasConductedClass => classes > 0;

  String get label =>
      subjectCode.isNotEmpty ? subjectCode : subjectName;
}

/// One student's attendance detail inside the currently selected HOD academic
/// context.
///
/// The backend only serves this for a student that belongs to that exact
/// context, so changing the student id in the request yields 403 with no data.
@immutable
class HodStudentAttendanceDetail {
  const HodStudentAttendanceDetail({
    required this.context,
    required this.studentId,
    required this.enrollmentNumber,
    required this.rollNumber,
    required this.studentName,
    required this.programName,
    required this.semesterName,
    required this.sectionName,
    required this.subjects,
    required this.totalPresent,
    required this.totalClasses,
    this.overallPercentage,
  });

  factory HodStudentAttendanceDetail.fromJson(Map<String, dynamic> json) =>
      HodStudentAttendanceDetail(
        context: json['context'] is Map
            ? HodAttendanceContext.fromJson(
                Map<String, dynamic>.from(json['context'] as Map))
            : HodAttendanceContext.empty,
        studentId: (json['studentId'] as num?)?.toInt() ?? 0,
        enrollmentNumber: json['enrollmentNumber'] as String? ?? '',
        rollNumber: json['rollNumber'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        programName: json['programName'] as String?,
        semesterName: json['semesterName'] as String?,
        sectionName: json['sectionName'] as String?,
        subjects: (json['subjects'] as List?)
                ?.whereType<Map>()
                .map((e) => HodStudentSubjectAttendance.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
        totalPresent: (json['totalPresent'] as num?)?.toInt() ?? 0,
        totalClasses: (json['totalClasses'] as num?)?.toInt() ?? 0,
        overallPercentage: (json['overallPercentage'] as num?)?.toDouble(),
      );

  final HodAttendanceContext context;
  final int studentId;
  final String enrollmentNumber;
  final String rollNumber;
  final String studentName;
  final String? programName;
  final String? semesterName;
  final String? sectionName;
  final List<HodStudentSubjectAttendance> subjects;
  final int totalPresent;
  final int totalClasses;
  final double? overallPercentage;

  String get identity =>
      enrollmentNumber.isNotEmpty ? enrollmentNumber : rollNumber;

  bool get hasConductedClasses => totalClasses > 0;
}

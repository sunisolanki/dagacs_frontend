import 'package:flutter/foundation.dart';

import 'hod_attendance_context.dart';

/// One subject responsible for a low-attendance student.
///
/// Only subjects whose <b>conducted classes</b> are themselves below the
/// threshold are listed. A subject with no conducted class is deliberately
/// absent: it is not the reason the student is low, and inventing a 0% entry for
/// it would fabricate data.
@immutable
class HodLowAttendanceSubject {
  const HodLowAttendanceSubject({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.present,
    required this.total,
    this.percentage,
  });

  factory HodLowAttendanceSubject.fromJson(Map<String, dynamic> json) =>
      HodLowAttendanceSubject(
        subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        present: (json['present'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
      );

  final int subjectId;
  final String subjectCode;
  final String subjectName;
  final int present;
  final int total;
  final double? percentage;

  String get label =>
      subjectCode.isNotEmpty ? subjectCode : subjectName;
}

/// One student below the application's fixed attendance threshold.
@immutable
class HodLowAttendanceStudent {
  const HodLowAttendanceStudent({
    required this.studentId,
    required this.enrollmentNumber,
    required this.rollNumber,
    required this.studentName,
    required this.sectionName,
    required this.programName,
    required this.semesterName,
    required this.academicSessionName,
    required this.presentCount,
    required this.totalClasses,
    this.percentage,
    required this.subjectsBelowThreshold,
    this.belowThresholdSubjects = const [],
  });

  factory HodLowAttendanceStudent.fromJson(Map<String, dynamic> json) =>
      HodLowAttendanceStudent(
        studentId: (json['studentId'] as num?)?.toInt() ?? 0,
        enrollmentNumber: json['enrollmentNumber'] as String? ?? '',
        rollNumber: json['rollNumber'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        sectionName: json['sectionName'] as String? ?? '',
        programName: json['programName'] as String?,
        semesterName: json['semesterName'] as String?,
        academicSessionName: json['academicSessionName'] as String?,
        presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
        totalClasses: (json['totalClasses'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
        subjectsBelowThreshold:
            (json['subjectsBelowThreshold'] as num?)?.toInt() ?? 0,
        belowThresholdSubjects: (json['belowThresholdSubjects'] as List?)
                ?.whereType<Map>()
                .map((e) => HodLowAttendanceSubject.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
      );

  final int studentId;
  final String enrollmentNumber;
  final String rollNumber;
  final String studentName;
  final String sectionName;
  final String? programName;
  final String? semesterName;
  final String? academicSessionName;
  final int presentCount;

  /// The denominator: <b>conducted classes</b> applicable to this student in the
  /// context. Never the attendance-record count.
  final int totalClasses;

  final double? percentage;
  final int subjectsBelowThreshold;
  final List<HodLowAttendanceSubject> belowThresholdSubjects;

  String get identity =>
      enrollmentNumber.isNotEmpty ? enrollmentNumber : rollNumber;

  /// True when the breakdown identified at least one responsible subject.
  bool get hasBreakdown => belowThresholdSubjects.isNotEmpty;
}

/// The context-scoped low-attendance report.
///
/// [thresholdPercentage] is the application's existing fixed 75% rule, echoed for
/// display. The client must not offer a "critical" band unless such a threshold
/// is defined by the application.
@immutable
class HodLowAttendanceReport {
  const HodLowAttendanceReport({
    required this.context,
    this.thresholdPercentage,
    required this.totalStudents,
    required this.belowThresholdCount,
    this.students = const [],
  });

  factory HodLowAttendanceReport.fromJson(Map<String, dynamic> json) =>
      HodLowAttendanceReport(
        context: json['context'] is Map
            ? HodAttendanceContext.fromJson(
                Map<String, dynamic>.from(json['context'] as Map))
            : HodAttendanceContext.empty,
        thresholdPercentage: (json['thresholdPercentage'] as num?)?.toDouble(),
        totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
        belowThresholdCount: (json['belowThresholdCount'] as num?)?.toInt() ?? 0,
        students: (json['students'] as List?)
                ?.whereType<Map>()
                .map((e) => HodLowAttendanceStudent.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
      );

  final HodAttendanceContext context;
  final double? thresholdPercentage;
  final int totalStudents;
  final int belowThresholdCount;
  final List<HodLowAttendanceStudent> students;

  bool get isEmpty => students.isEmpty;
}

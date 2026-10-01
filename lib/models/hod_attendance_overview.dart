import 'package:flutter/foundation.dart';

import 'hod_attendance_context.dart';

/// One band of the student attendance distribution of an academic context.
///
/// The bands are the application's pre-existing display bands. A student with no
/// conducted class at all belongs to no band and is reported separately as
/// [HodAttendanceOverview.noConductedClasses] rather than being forced into 0%.
/// A student who was simply never marked in a conducted class does belong to
/// "Below 75%": they genuinely attended 0%.
@immutable
class HodAttendanceDistribution {
  const HodAttendanceDistribution({
    required this.band,
    required this.label,
    required this.studentCount,
  });

  factory HodAttendanceDistribution.fromJson(Map<String, dynamic> json) =>
      HodAttendanceDistribution(
        band: json['band'] as String? ?? '',
        label: json['label'] as String? ?? '',
        studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      );

  final String band;
  final String label;
  final int studentCount;
}

/// One subject line of the academic-context overview.
///
/// [classesConducted] is the subject's own conducted-class count and
/// [totalClasses] is that count measured against the enrolled population of the
/// context, so it is the denominator behind [percentage]. A student who was
/// never marked in a conducted class is still inside [totalClasses].
@immutable
class HodAttendanceSubjectSummary {
  const HodAttendanceSubjectSummary({
    required this.subjectId,
    required this.subjectOfferingId,
    required this.subjectCode,
    required this.subjectName,
    required this.facultyNames,
    required this.classesConducted,
    required this.presentCount,
    required this.totalClasses,
    required this.students,
    required this.studentsBelowThreshold,
    this.percentage,
  });

  factory HodAttendanceSubjectSummary.fromJson(Map<String, dynamic> json) =>
      HodAttendanceSubjectSummary(
        subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
        subjectOfferingId: (json['subjectOfferingId'] as num?)?.toInt(),
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        facultyNames: (json['facultyNames'] as List?)
                ?.where((e) => e != null)
                .map((e) => e.toString())
                .toList(growable: false) ??
            const [],
        classesConducted: (json['classesConducted'] as num?)?.toInt() ?? 0,
        presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
        totalClasses: (json['totalClasses'] as num?)?.toInt() ?? 0,
        students: (json['students'] as num?)?.toInt() ?? 0,
        studentsBelowThreshold:
            (json['studentsBelowThreshold'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
      );

  final int subjectId;
  final int? subjectOfferingId;
  final String subjectCode;
  final String subjectName;
  final List<String> facultyNames;

  /// <b>Conducted classes</b> of this subject in the context.
  final int classesConducted;
  final int presentCount;

  /// The denominator: conducted classes measured against the enrolled students.
  final int totalClasses;

  /// Enrolled students of the context, i.e. the population [totalClasses] was
  /// measured against. Counting, never filtering by attendance: a student with no
  /// marks in this subject is still part of the denominator.
  final int students;

  /// Students below the threshold in <b>this subject</b>.
  ///
  /// A subject with no conducted class reports 0, not "everyone fails": with no
  /// denominator there is no percentage to fall short of.
  final int studentsBelowThreshold;

  /// Null when nothing was conducted - never a fabricated 0%.
  final double? percentage;

  bool get hasConductedClasses => totalClasses > 0;

  String get facultyLabel =>
      facultyNames.isEmpty ? 'No faculty assigned' : facultyNames.join(', ');
}

/// The academic-context attendance overview.
///
/// Every metric comes from an authoritative backend aggregate. A metric the
/// backend has no source for is null and the UI renders an explicit unavailable
/// state — never a fabricated zero.
@immutable
class HodAttendanceOverview {
  const HodAttendanceOverview({
    required this.context,
    required this.totalStudents,
    required this.overallPresentCount,
    required this.overallTotalClasses,
    this.overallPercentage,
    required this.belowThresholdCount,
    this.classesConducted,
    this.thresholdPercentage,
    this.distribution = const [],
    required this.noConductedClasses,
    this.subjects = const [],
  });

  factory HodAttendanceOverview.fromJson(Map<String, dynamic> json) =>
      HodAttendanceOverview(
        context: json['context'] is Map
            ? HodAttendanceContext.fromJson(
                Map<String, dynamic>.from(json['context'] as Map))
            : HodAttendanceContext.empty,
        totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
        overallPresentCount: (json['overallPresentCount'] as num?)?.toInt() ?? 0,
        overallTotalClasses: (json['overallTotalClasses'] as num?)?.toInt() ?? 0,
        overallPercentage: (json['overallPercentage'] as num?)?.toDouble(),
        belowThresholdCount: (json['belowThresholdCount'] as num?)?.toInt() ?? 0,
        classesConducted: (json['classesConducted'] as num?)?.toInt(),
        thresholdPercentage: (json['thresholdPercentage'] as num?)?.toDouble(),
        distribution: (json['distribution'] as List?)
                ?.whereType<Map>()
                .map((e) => HodAttendanceDistribution.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
        noConductedClasses: (json['noConductedClasses'] as num?)?.toInt() ?? 0,
        subjects: (json['subjects'] as List?)
                ?.whereType<Map>()
                .map((e) => HodAttendanceSubjectSummary.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
      );

  final HodAttendanceContext context;
  final int totalStudents;
  final int overallPresentCount;

  /// The denominator: <b>conducted attendance sessions</b> applicable to the
  /// context. Never the count of attendance records.
  final int overallTotalClasses;

  final double? overallPercentage;
  final int belowThresholdCount;

  /// Conducted classes in the context, or null when the context was not fully
  /// resolved and the metric would be ambiguous.
  final int? classesConducted;

  final double? thresholdPercentage;
  final List<HodAttendanceDistribution> distribution;

  /// Students with no conducted class at all, so their percentage is genuinely
  /// unavailable. A student with classes but no marks is <b>not</b> counted here:
  /// they report a real 0%.
  final int noConductedClasses;

  final List<HodAttendanceSubjectSummary> subjects;

  /// True when at least one class was conducted, so a percentage exists at all.
  bool get hasConductedClasses => overallTotalClasses > 0;
}

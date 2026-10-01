import 'package:flutter/foundation.dart';

/// The academic context a Phase 3 HOD attendance report was computed for.
///
/// Returned by the backend alongside every report so the UI can state exactly
/// which context the numbers belong to, instead of relying on whatever the
/// user happens to have selected in the context bar.
///
/// The department is deliberately absent: it is derived from the JWT on the
/// server and is not a report dimension.
@immutable
class HodAttendanceContext {
  const HodAttendanceContext({
    this.academicSessionId,
    this.academicSessionName,
    this.programId,
    this.programName,
    this.semesterId,
    this.semesterName,
    this.sectionId,
    this.sectionName,
    this.complete = false,
  });

  factory HodAttendanceContext.fromJson(Map<String, dynamic> json) =>
      HodAttendanceContext(
        academicSessionId: (json['academicSessionId'] as num?)?.toInt(),
        academicSessionName: json['academicSessionName'] as String?,
        programId: (json['programId'] as num?)?.toInt(),
        programName: json['programName'] as String?,
        semesterId: (json['semesterId'] as num?)?.toInt(),
        semesterName: json['semesterName'] as String?,
        sectionId: (json['sectionId'] as num?)?.toInt(),
        sectionName: json['sectionName'] as String?,
        complete: json['complete'] == true,
      );

  final int? academicSessionId;
  final String? academicSessionName;
  final int? programId;
  final String? programName;
  final int? semesterId;
  final String? semesterName;
  final int? sectionId;
  final String? sectionName;

  /// True when all four mandatory levels are present. The matrix is never
  /// served for a partial context, so this drives the "select the academic
  /// context" state.
  final bool complete;

  /// The empty context, used before anything has been selected.
  static const HodAttendanceContext empty = HodAttendanceContext();

  /// A single human-readable line describing the context, for report headers.
  String get label {
    final parts = <String>[
      if (academicSessionName != null) academicSessionName!,
      if (programName != null) programName!,
      if (semesterName != null) semesterName!,
      if (sectionName != null) sectionName!,
    ];
    return parts.isEmpty ? 'No academic context selected' : parts.join(' · ');
  }
}

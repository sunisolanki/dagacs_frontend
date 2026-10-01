/// Phase 4A: the closed set of HOD report types that have their own file
/// representation, and the single place a report type is mapped to one.
///
/// <b>Why this is an enum and not a `switch` in the widget.</b> Phase 4A removed a
/// real defect: the export path used to route <i>every</i> academic-context
/// report through the matrix exporter, so choosing "Attendance Overview" and
/// clicking Excel silently produced the Attendance Matrix. The fix that keeps
/// that defect from returning is not a longer `switch` — it is making the set of
/// answers closed, so adding a sixth report type becomes a <b>compile error</b>
/// instead of a silently wrong file.
///
/// Nothing here decides <i>what</i> an export contains, calculates an attendance
/// figure, or talks to the network. It only answers two questions:
/// * which report type is this string, and
/// * is that report type fileable from here at all.
///
/// The five report types are deliberately prefixed (`context-overview`,
/// `context-matrix`, …) because the pre-existing M7.1/M7.2 department reports
/// use their own keys, and `low-attendance` exists in both namespaces. A shared
/// key would make a section switch ambiguous and could send a reader to the
/// other report.
enum HodReportExportKind {
  /// Attendance Overview — the context-wide subject summary.
  overview('context-overview', 'Attendance Overview'),

  /// Attendance Matrix — the student × subject cross-tab.
  matrix('context-matrix', 'Attendance Matrix'),

  /// Low Attendance — the threshold report, with the subjects responsible.
  lowAttendance('context-low-attendance', 'Low Attendance'),

  /// Student Attendance <i>list</i>. Not fileable from the hub.
  studentList('context-students', 'Student Attendance'),

  /// Subject Attendance <i>list</i>. Not fileable from the hub.
  subjectList('context-subjects', 'Subject Attendance');

  const HodReportExportKind(this.reportType, this.label);

  /// The report-type key the Reports screen uses for this report.
  final String reportType;

  /// The human report name, used in labels, tooltips and error messages.
  ///
  /// <b>It is the report's own name, never the file's name.</b> A tooltip that
  /// said "Attendance Matrix" must never be attached to a button that downloads
  /// the overview, which is the entire class of bug this enum exists to prevent.
  final String label;

  /// True when this report has a single entity to file, so it can be exported
  /// from the Reports hub.
  ///
  /// <b>Why the two lists are excluded.</b> "Student Attendance" and "Subject
  /// Attendance" show <i>every</i> student / <i>every</i> subject in the
  /// context, not one of them. There is no single entity to name in a file, and
  /// quietly exporting "the first student" would be exactly the wrong-file bug
  /// Phase 4A exists to remove. Each is exported from its own detail screen,
  /// where the entity is the one the HOD actually opened.
  bool get isExportableFromHub => this != studentList && this != subjectList;

  /// The copy shown when a non-fileable report section is selected in the hub.
  ///
  /// It tells the reader the exact next action rather than just refusing.
  String get openAnEntityToExportMessage {
    switch (this) {
      case studentList:
        return 'Open a student to export that student\'s attendance report.';
      case subjectList:
        return 'Open a subject to export that subject\'s attendance report.';
      case overview:
      case matrix:
      case lowAttendance:
        return 'Open a student or subject to export its report.';
    }
  }

  /// The report type for [reportType], or null when it is not one of the five.
  static HodReportExportKind? forReportType(String? reportType) {
    for (final kind in HodReportExportKind.values) {
      if (kind.reportType == reportType) return kind;
    }
    return null;
  }

  /// The report types that own an export from the Reports hub, in the order they
  /// are presented.
  static List<HodReportExportKind> get exportableFromHub => HodReportExportKind
      .values
      .where((kind) => kind.isExportableFromHub)
      .toList(growable: false);
}

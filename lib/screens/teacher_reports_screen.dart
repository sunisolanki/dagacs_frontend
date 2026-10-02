import 'package:flutter/material.dart';

import '../repositories/report_repository.dart';
import '../repositories/teacher_repository.dart';
import '../services/report_file_downloader.dart';
import '../widgets/student_attendance_report_view.dart';
import '../core/session/session_controller.dart';
import '../widgets/app_module_scaffold.dart';

/// Teacher Reports (M7.3) - the student-wise, date-wise attendance register.
///
/// This page IS the teacher's attendance report. It picks one of the teacher's
/// own assignments (subject + section/batch), then renders the
/// enrollment-ordered matrix with one column per CONDUCTED attendance session
/// and per-student totals. The Excel and PDF exports use the same dataset, so
/// the preview and the downloaded files can never disagree.
///
/// Self-scope is always derived from the JWT: the assignment list the selectors
/// are built from is the same list the backend re-validates for authorization,
/// so the page has no teacher/department selector and cannot widen its own
/// scope.
class TeacherReportsScreen extends StatelessWidget {
  const TeacherReportsScreen({
    super.key,
    required this.reportRepository,
    required this.teacherRepository,
    this.downloadFile = downloadReportFile,
    this.session,
  });

  final ReportRepository reportRepository;
  final TeacherRepository teacherRepository;
  final ReportFileDownloader downloadFile;

  /// Phase 5.5: see StudentAttendanceScreen.session. Optional so existing
  /// construction sites keep working; when supplied the screen joins the shared
  /// navigation frame so a teacher on a phone can reach the rest of the app.
  final SessionController? session;

  @override
  Widget build(BuildContext context) {
    final body = StudentAttendanceReportView(
      reportRepository: reportRepository,
      teacherRepository: teacherRepository,
      downloadFile: downloadFile,
    );

    final session = this.session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teacher Attendance Report')),
        body: body,
      );
    }
    return AppModuleScaffold(
      session: session,
      title: 'Teacher Attendance Report',
      body: body,
    );
  }
}

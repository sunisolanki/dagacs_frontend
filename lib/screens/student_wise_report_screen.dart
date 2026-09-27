import 'package:flutter/material.dart';

import '../repositories/report_repository.dart';
import '../repositories/teacher_repository.dart';
import '../services/report_file_downloader.dart';
import '../widgets/student_attendance_report_view.dart';

/// Deep link to the student-wise attendance register.
///
/// The register itself lives in [StudentAttendanceReportView], which the
/// Reports page also hosts, so this route and the Reports page always show the
/// same report. Retained as a distinct route so the existing
/// `teacherStudentWise` navigation entry keeps working.
class StudentWiseReportScreen extends StatelessWidget {
  const StudentWiseReportScreen({
    super.key,
    required this.reportRepository,
    required this.teacherRepository,
    this.downloadFile = downloadReportFile,
  });

  final ReportRepository reportRepository;
  final TeacherRepository teacherRepository;
  final ReportFileDownloader downloadFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student-Wise Register')),
      body: StudentAttendanceReportView(
        reportRepository: reportRepository,
        teacherRepository: teacherRepository,
        downloadFile: downloadFile,
      ),
    );
  }
}

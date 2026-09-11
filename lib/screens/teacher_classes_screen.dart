import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/theme/dagacs_theme.dart';
import '../models/attendance_session.dart';
import '../models/teacher_assignment.dart';
import '../network/api_exception.dart';
import '../repositories/teacher_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// Teacher "My Classes" home tile screen (M9.4).
///
/// Loads the authenticated teacher's assignments ONCE from the TEACHER-only
/// `GET /api/teacher/assignments` endpoint. The assignment DTO already carries
/// every piece of display context (Subject, Semester, AcademicSession,
/// Program, Department, Section, Batch) — the client never reconstructs
/// context through Master Data endpoints and never issues N+1 requests.
class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({super.key, required this.teacherRepository});

  final TeacherRepository teacherRepository;

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  bool _loading = true;
  String? _error;
  List<TeacherAssignment> _assignments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assignments = await widget.teacherRepository.getMyAssignments();
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userMessageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading your classes.';
        _loading = false;
      });
    }
  }

  Future<void> _takeAttendance(TeacherAssignment assignment) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.createSession,
      arguments: assignment,
    );
    if (result is AttendanceSession && result.id != null && mounted) {
      await Navigator.of(context).pushNamed(
        AppRoutes.markAttendance,
        arguments: result.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Classes')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading your classes...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_assignments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  AppEmptyState(
                    key: Key('my-classes-empty'),
                    icon: Icons.class_outlined,
                    message:
                        'No classes assigned yet. Contact your administrator.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        key: const Key('my-classes-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          DagacsSpace.lg,
          DagacsSpace.md,
          DagacsSpace.lg,
          96,
        ),
        itemCount: _assignments.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const AppConstrainedMax(
              maxWidth: 1120,
              child: AppPageHeader(
                icon: Icons.class_outlined,
                title: 'Your classes',
                subtitle: 'Tap Take Attendance on an assigned class to mark it.',
              ),
            );
          }
          final assignment = _assignments[index - 1];
          return AppConstrainedMax(
            maxWidth: 1120,
            child: Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm + 2),
              child: _ClassCard(
                assignment: assignment,
                onTakeAttendance: () => _takeAttendance(assignment),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.assignment,
    required this.onTakeAttendance,
  });

  final TeacherAssignment assignment;
  final VoidCallback onTakeAttendance;

  static String _join(String separator, List<String?> parts) => parts
      .where((p) => p != null && p.trim().isNotEmpty)
      .map((p) => p!.trim())
      .join(separator);

  List<(String, String)> _rows() {
    final subject = _join(' — ', [assignment.subjectCode, assignment.subjectName]);
    final session =
        _join(' — ', [assignment.sessionName, assignment.programName, assignment.departmentName]);
    final section = assignment.sectionName?.trim().isNotEmpty == true
        ? assignment.sectionName!.trim()
        : (assignment.sectionCode?.trim() ?? '');
    final rows = <(String, String)>[];
    if (subject.isNotEmpty) rows.add(('Subject', subject));
    if (assignment.semesterName?.trim().isNotEmpty ?? false) {
      rows.add(('Semester', assignment.semesterName!.trim()));
    }
    if (session.isNotEmpty) rows.add(('Academic context', session));
    if (section.isNotEmpty) rows.add(('Section', section));
    if (assignment.batchCode?.trim().isNotEmpty ?? false) {
      rows.add(('Batch', assignment.batchCode!.trim()));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _rows();
    return AppCard(
      key: Key('my-class-tile-${assignment.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBadge(icon: Icons.class_outlined, size: 46),
          const SizedBox(width: DagacsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows) ...[
                  if (row != rows.first) const SizedBox(height: 6),
                  Text(
                    row.$1.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: DagacsColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    row.$2,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (rows.isEmpty)
                  Text(
                    'Class ${assignment.id ?? ''}',
                    style: theme.textTheme.titleSmall,
                  ),
                const SizedBox(height: DagacsSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: Key('my-class-take-attendance-${assignment.id}'),
                    onPressed: onTakeAttendance,
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Take Attendance'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
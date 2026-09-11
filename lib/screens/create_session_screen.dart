import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/attendance_session.dart';
import '../models/attendance_session_create_request.dart';
import '../models/teacher_assignment.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/teacher_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// Form for creating a new attendance session (M9.4).
///
/// Class selection is assignment-driven: the class dropdown (or the locked
/// preselected class when arriving from My Classes) is populated from the
/// teacher's own assignments via `GET /api/teacher/assignments`. Subject and
/// Section IDs are always derived from the selected [TeacherAssignment] — no
/// manual ID entry remains. When the backend reports a duplicate (409) the
/// existing session is looked up locally from the session list and offered to
/// the teacher to open.
class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({
    super.key,
    required this.attendanceRepository,
    required this.teacherRepository,
    this.preselectedAssignment,
  });

  final AttendanceRepository attendanceRepository;
  final TeacherRepository teacherRepository;

  /// Set when the screen is opened from My Classes → Take Attendance. The
  /// class is then preselected and locked (not replaceable).
  final TeacherAssignment? preselectedAssignment;

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  TeacherAssignment? _selectedAssignment;
  List<TeacherAssignment> _assignments = const [];
  bool _loadingAssignments = true;
  String? _assignmentsError;
  final _lecturePeriodController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;
  bool _resolvingDuplicate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedAssignment = widget.preselectedAssignment;
    if (widget.preselectedAssignment == null) {
      _loadAssignments();
    } else {
      _loadingAssignments = false;
    }
  }

  @override
  void dispose() {
    _lecturePeriodController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _assignmentsError = null;
    });
    try {
      final assignments = await widget.teacherRepository.getMyAssignments();
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _loadingAssignments = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _assignmentsError = userMessageFor(e);
        _loadingAssignments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assignmentsError = 'Something went wrong while loading your classes.';
        _loadingAssignments = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  bool get _disabled {
    if (_isLoading || _resolvingDuplicate) return true;
    if (widget.preselectedAssignment == null && _assignments.isEmpty) {
      return true;
    }
    return false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final assignment = _selectedAssignment;
    if (assignment == null) return;
    final subjectId = assignment.subjectId;
    final sectionId = assignment.sectionId;
    if (subjectId == null || sectionId == null) {
      setState(() {
        _error =
            'Selected class is missing subject or section information.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final created = await widget.attendanceRepository.createSession(
        AttendanceSessionCreateRequest(
          subjectId: subjectId,
          sectionId: sectionId,
          lecturePeriod: _lecturePeriodController.text.trim(),
          date: _dateController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await _resolveDuplicate(subjectId, sectionId);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = switch (e.statusCode) {
          400 => e.message.isNotEmpty ? e.message : 'Validation error.',
          403 => 'You are not assigned to this subject and section.',
          404 => 'Subject or section not found.',
          -1 => kNetworkErrorMessage,
          _ => e.statusCode >= 500 ? kServerErrorMessage : e.message,
        };
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to create session. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Backend uniqueness rule is untouched; on 409 the existing session is
  /// found locally from the teacher's own session list and offered to open.
  Future<void> _resolveDuplicate(int subjectId, int sectionId) async {
    setState(() {
      _resolvingDuplicate = true;
      _error = null;
    });
    try {
      final sessions = await widget.attendanceRepository.getSessions();
      AttendanceSession? existing;
      for (final session in sessions) {
        if (session.subjectId == subjectId &&
            session.sectionId == sectionId &&
            session.date == _dateController.text.trim() &&
            session.lecturePeriod == _lecturePeriodController.text.trim()) {
          existing = session;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resolvingDuplicate = false;
      });
      if (existing == null) {
        setState(() {
          _error = 'A session already exists for this class and date, '
              'but it could not be opened.';
        });
        return;
      }
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.info_outline, color: DagacsColors.info),
          title: const Text('Session already exists'),
          content: const Text(
              'Attendance session already exists for this class and date.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('duplicate-open-existing'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Existing'),
            ),
          ],
        ),
      );
      if (open == true && mounted) {
        Navigator.pop(context, existing);
      }
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resolvingDuplicate = false;
        _error =
            'Could not open the existing attendance session. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resolvingDuplicate = false;
        _error =
            'Could not open the existing attendance session. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DagacsSpace.lg),
        child: AppConstrainedMax(
          maxWidth: 640,
          child: Form(
            key: _formKey,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppPageHeader(
                    icon: Icons.event_available_outlined,
                    title: 'Create attendance session',
                    subtitle: 'Record a class before marking attendance.',
                  ),
                  const SizedBox(height: DagacsSpace.md),
                  ..._buildClassSelector(),
                  AppFormTextField(
                    label: 'Lecture period',
                    controller: _lecturePeriodController,
                    hintText: 'For example, 1st Period',
                    prefixIcon: Icons.schedule_outlined,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Lecture period is required'
                        : null,
                  ),
                  AppFormTextField(
                    label: 'Date',
                    controller: _dateController,
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icons.calendar_today_outlined,
                    suffixIcon: IconButton(
                      tooltip: 'Choose date',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: _pickDate,
                    ),
                    onTap: _pickDate,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Date is required'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: DagacsSpace.xs),
                    Text(_error!,
                        style: const TextStyle(
                            color: DagacsColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: DagacsSpace.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('create-session-submit'),
                      onPressed: _disabled ? null : _submit,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading || _resolvingDuplicate)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.add_task_outlined),
                          const SizedBox(width: DagacsSpace.sm),
                          Flexible(
                            child: Text(
                              _isLoading || _resolvingDuplicate
                                  ? 'Creating…'
                                  : 'Create session',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Class selection area: locked preselected class, assignment dropdown, or
  /// the zero-assignment notice (no manual ID fallback).
  List<Widget> _buildClassSelector() {
    if (widget.preselectedAssignment != null) {
      return [_lockedClassField(widget.preselectedAssignment!)];
    }
    if (_loadingAssignments) {
      return const [
        Padding(
          padding: EdgeInsets.only(bottom: DagacsSpace.md),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: DagacsSpace.md),
              Flexible(
                child: Text(
                  'Loading your classes...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    if (_assignmentsError != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: DagacsSpace.md),
          child: AppErrorState(
            message: _assignmentsError!,
            onRetry: _loadAssignments,
          ),
        ),
      ];
    }
    if (_assignments.isEmpty) {
      return [
        Container(
          key: const Key('no-classes-assigned'),
          padding: const EdgeInsets.all(DagacsSpace.md),
          margin: const EdgeInsets.only(bottom: DagacsSpace.md),
          decoration: BoxDecoration(
            color: DagacsColors.infoBg,
            borderRadius: BorderRadius.circular(DagacsRadius.md),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: DagacsColors.info),
              SizedBox(width: DagacsSpace.sm),
              Expanded(
                child: Text(
                  'No classes assigned yet. Contact your administrator.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      AppFormDropdown<TeacherAssignment>(
        label: 'Class',
        value: _selectedAssignment,
        items: [
          for (final assignment in _assignments)
            DropdownMenuItem<TeacherAssignment>(
              value: assignment,
              child: Text(_assignmentContext(assignment)),
            ),
        ],
        onChanged: (value) => setState(() => _selectedAssignment = value),
        validator: (value) => value == null ? 'Please select a class' : null,
      ),
    ];
  }

  Widget _lockedClassField(TeacherAssignment assignment) {
    return Container(
      key: const Key('preselected-class-lock'),
      padding: const EdgeInsets.all(DagacsSpace.md),
      margin: const EdgeInsets.only(bottom: DagacsSpace.md),
      decoration: BoxDecoration(
        color: DagacsColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DagacsRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline,
              color: DagacsColors.textSecondary, size: 18),
          const SizedBox(width: DagacsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLASS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DagacsColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _assignmentContext(assignment),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Selected from My Classes. Locked.',
                  style: const TextStyle(
                      fontSize: 12, color: DagacsColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _assignmentContext(TeacherAssignment assignment) {
    String join(String separator, List<String?> parts) => parts
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(separator);

    final subject =
        join(' — ', [assignment.subjectCode, assignment.subjectName]);
    final semester = assignment.semesterName?.trim() ?? '';
    final session = join(' — ', [
      assignment.sessionName,
      assignment.programName,
      assignment.departmentName,
    ]);
    final sectionValue = assignment.sectionName?.trim().isNotEmpty == true
        ? assignment.sectionName!.trim()
        : (assignment.sectionCode?.trim() ?? '');
    final batch = assignment.batchCode?.trim() ?? '';

    return <String>[subject, semester, session, sectionValue, batch]
        .where((p) => p.isNotEmpty)
        .join(' · ');
  }
}
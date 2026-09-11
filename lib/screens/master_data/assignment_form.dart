import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/program.dart';
import '../../models/section.dart';
import '../../models/subject_offering.dart';
import '../../models/teacher.dart';
import '../../models/teacher_assignment.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [TeacherAssignment].
///
/// Collects exactly the three foreign identities of the backend request
/// contract: Teacher, Subject Offering and Section. All other context
/// (Subject, Semester, AcademicSession, Program, Department, Batch) is derived
/// server-side and never collected here.
Future<TeacherAssignment?> showTeacherAssignmentForm(
  BuildContext context,
  MasterDataRepository repository, {
  TeacherAssignment? initial,
}) {
  return showDialog<TeacherAssignment>(
    context: context,
    builder: (_) => _TeacherAssignmentFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _TeacherAssignmentFormDialog extends StatefulWidget {
  const _TeacherAssignmentFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final TeacherAssignment? initial;

  @override
  State<_TeacherAssignmentFormDialog> createState() =>
      _TeacherAssignmentFormDialogState();
}

class _TeacherAssignmentFormDialogState
    extends State<_TeacherAssignmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _teacherId;
  int? _subjectOfferingId;
  int? _sectionId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Teacher> _teachers = const [];
  List<SubjectOffering> _offerings = const [];
  List<Section> _sections = const [];
  Map<int, AcademicSession> _sessionsById = const {};
  Map<int, Program> _programsById = const {};

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.getTeachers(),
        widget.repository.getSubjectOfferings(),
        widget.repository.getSections(),
        widget.repository.getAcademicSessions(),
        widget.repository.getPrograms(),
      ]);
      if (!mounted) return;
      final teachers = results[0] as List<Teacher>;
      final offerings = results[1] as List<SubjectOffering>;
      final sections = results[2] as List<Section>;
      final sessions = results[3] as List<AcademicSession>;
      final programs = results[4] as List<Program>;
      setState(() {
        _teachers = teachers;
        _offerings = offerings;
        _sections = sections;
        _sessionsById = {
          for (final session in sessions)
            if (session.id != null) session.id!: session,
        };
        _programsById = {
          for (final program in programs)
            if (program.id != null) program.id!: program,
        };
        _teacherId = widget.initial?.teacherId ?? _teachers.firstOrNull?.id;
        _subjectOfferingId =
            widget.initial?.subjectOfferingId ?? _offerings.firstOrNull?.id;
        _sectionId = widget.initial?.sectionId ?? _sections.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load reference data.';
        _loadingReferences = false;
      });
    }
  }

  String _teacherLabel(Teacher t) {
    final name = t.fullName?.trim();
    final designation = t.designation?.trim();
    final base = (name == null || name.isEmpty)
        ? (t.email?.trim().isNotEmpty == true ? t.email! : 'Teacher unavailable')
        : name;
    if (designation == null || designation.isEmpty) return base;
    return '$base — $designation';
  }

  String _semesterContextLabel(AcademicSession? shallow) {
    if (shallow == null) return 'Semester unavailable';
    final session = _sessionsById[shallow.id] ?? shallow;
    return academicSessionContextLabel(session, programsById: _programsById);
  }

  String _offeringLabel(SubjectOffering o) {
    final subjectCode = o.subject?.code?.trim();
    final subjectName = o.subject?.name?.trim();
    final subject = (subjectCode == null || subjectCode.isEmpty)
        ? (subjectName?.isNotEmpty == true ? subjectName : 'Subject unavailable')
        : (subjectName == null || subjectName.isEmpty
            ? subjectCode
            : '$subjectCode — $subjectName');
    final semesterName = o.semester?.name?.trim();
    final context = _semesterContextLabel(o.semester?.academicSession);
    final semester = (semesterName == null || semesterName.isEmpty)
        ? context
        : '$context — $semesterName';
    return '$subject · $semester';
  }

  String _sectionLabel(Section s) {
    final code = s.sectionCode?.trim();
    final name = s.name?.trim();
    final section = (code == null || code.isEmpty)
        ? (name?.isNotEmpty == true ? name : 'Section unavailable')
        : (name == null || name.isEmpty ? code : '$code — $name');
    final batchCode = s.batch?.batchCode?.trim();
    final batch = (batchCode == null || batchCode.isEmpty)
        ? 'Batch unavailable'
        : 'Batch $batchCode';
    return '$section · $batch';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = TeacherAssignmentRequest(
      teacherId: _teacherId!,
      subjectOfferingId: _subjectOfferingId!,
      sectionId: _sectionId!,
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateTeacherAssignment(widget.initial!.id!, request)
          : await widget.repository.createTeacherAssignment(request);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = userMessageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Something went wrong while saving. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(child: _buildContent());
  }

  Widget _buildContent() {
    if (_loadingReferences) {
      return SizedBox(
          height: 240,
          child: AppLoadingState(message: 'Loading reference data...'));
    }
    if (_referencesError != null) {
      return SizedBox(
        height: 240,
        child: AppErrorState(
            message: _referencesError!, onRetry: _loadReferences),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit
                ? 'Edit Teacher Assignment'
                : 'Add Teacher Assignment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppFormDropdown<int>(
            key: const Key('field-teacher'),
            label: 'Teacher',
            value: _teacherId,
            items: _teachers
                .where((t) => t.id != null)
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        _teacherLabel(t),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _teacherId = v),
            validator: (v) => v == null ? 'Teacher is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-subject-offering'),
            label: 'Subject Offering',
            value: _subjectOfferingId,
            items: _offerings
                .where((o) => o.id != null)
                .map((o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(
                        _offeringLabel(o),
                        maxLines: 3,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _subjectOfferingId = v),
            validator: (v) =>
                v == null ? 'Subject offering is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-section'),
            label: 'Section',
            value: _sectionId,
            items: _sections
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        _sectionLabel(s),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _sectionId = v),
            validator: (v) => v == null ? 'Section is required' : null,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          AppFormActions(
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
            submitting: _submitting,
            submitKey: 'submit-teacher-assignment',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/batch.dart';
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
  int? _batchId;
  int? _sectionId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Teacher> _teachers = const [];
  List<SubjectOffering> _offerings = const [];
  List<Batch> _batches = const [];
  List<Section> _sections = const [];
  Map<int, AcademicSession> _sessionsById = const {};
  Map<int, Program> _programsById = const {};

  bool get _isEdit => widget.initial != null;

  SubjectOffering? get _selectedOffering {
    final id = _subjectOfferingId;
    if (id == null) return null;
    for (final o in _offerings) {
      if (o.id == id) return o;
    }
    return null;
  }

  int? get _offeringSessionId =>
      _selectedOffering?.semester?.academicSessionId;

  int? get _initialBatchId {
    final sectionId = widget.initial?.sectionId;
    if (sectionId != null) {
      for (final s in _sections) {
        if (s.id == sectionId) return s.batchId;
      }
    }
    return widget.initial?.batchId;
  }

  List<Batch> get _selectableBatches {
    final sessionId = _offeringSessionId;
    final initialBatchId = widget.initial?.batchId;
    return [
      for (final b in _batches)
        if (b.id != null &&
            ((sessionId != null && b.academicSessionId == sessionId) ||
                (widget.initial?.sectionId != null &&
                    b.id == _initialBatchId) ||
                (initialBatchId != null && b.id == initialBatchId)))
          b,
    ];
  }

  List<Section> get _sectionsForBatch {
    final batchId = _batchId;
    if (batchId == null) return const [];
    return [
      for (final s in _sections)
        if (s.id != null && s.batchId == batchId) s,
    ];
  }

  int? _resolveInitialBatchId() {
    final preferred = _initialBatchId;
    if (preferred != null) return preferred;
    return _selectableBatches.firstOrNull?.id;
  }

  int? _resolveInitialSectionId() {
    final preferred = widget.initial?.sectionId;
    if (preferred == null) return null;
    final batchId = _batchId;
    if (batchId == null) return null;
    for (final s in _sectionsForBatch) {
      if (s.id == preferred) return preferred;
    }
    return null;
  }

  List<Teacher> get _selectableTeachers {
    final currentTeacherId = widget.initial?.teacherId;
    return [
      for (final t in _teachers)
        if (t.id != null &&
            (t.status == 'ACTIVE' ||
                (_isEdit &&
                    currentTeacherId != null &&
                    t.id == currentTeacherId)))
          t,
    ];
  }

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
        widget.repository.getBatches(),
        widget.repository.getSections(),
        widget.repository.getAcademicSessions(),
        widget.repository.getPrograms(),
      ]);
      if (!mounted) return;
      final teachers = results[0] as List<Teacher>;
      final offerings = results[1] as List<SubjectOffering>;
      final batches = results[2] as List<Batch>;
      final sections = results[3] as List<Section>;
      final sessions = results[4] as List<AcademicSession>;
      final programs = results[5] as List<Program>;
      setState(() {
        _teachers = teachers;
        _offerings = offerings;
        _batches = batches;
        _sections = sections;
        _sessionsById = {
          for (final session in sessions)
            if (session.id != null) session.id!: session,
        };
        _programsById = {
          for (final program in programs)
            if (program.id != null) program.id!: program,
        };
        _teacherId =
            widget.initial?.teacherId ?? _selectableTeachers.firstOrNull?.id;
        _subjectOfferingId =
            widget.initial?.subjectOfferingId ?? _offerings.firstOrNull?.id;
        _batchId = _resolveInitialBatchId();
        _sectionId = _resolveInitialSectionId();
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

  String _batchLabel(Batch b) {
    final code = b.batchCode?.trim();
    final name = b.name?.trim();
    if (code == null || code.isEmpty) {
      return (name == null || name.isEmpty) ? 'Batch unavailable' : name;
    }
    if (name == null || name.isEmpty) return 'Batch $code';
    return 'Batch $code — $name';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final batchId = _batchId;
    if (batchId == null) {
      setState(() {
        _submitError = 'Batch is required.';
      });
      return;
    }
    if (_sectionsForBatch.isEmpty) {
      // Phase 2: a batch with no sections gets a batch-level assignment.
      final request = TeacherAssignmentRequest(
        teacherId: _teacherId!,
        subjectOfferingId: _subjectOfferingId!,
        batchId: batchId,
      );
      await _save(request);
      return;
    }
    if (_sectionId == null) {
      setState(() {
        _submitError = 'Please select a section for this batch.';
      });
      return;
    }
    final request = TeacherAssignmentRequest(
      teacherId: _teacherId!,
      subjectOfferingId: _subjectOfferingId!,
      sectionId: _sectionId!,
    );
    await _save(request);
  }

  Future<void> _save(TeacherAssignmentRequest request) async {
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
            items: _selectableTeachers
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
            onChanged: (v) => setState(() {
              _subjectOfferingId = v;
              _batchId = _selectableBatches.firstOrNull?.id;
              _sectionId = null;
            }),
            validator: (v) =>
                v == null ? 'Subject offering is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-batch'),
            label: 'Batch',
            value: _batchId,
            items: _selectableBatches
                .map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        _batchLabel(b),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _batchId = v;
              _sectionId = null;
            }),
            validator: (v) => v == null ? 'Batch is required' : null,
          ),
          if (_batchId != null && _sectionsForBatch.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No sections exist in this batch. The assignment will be '
                'created at the batch level.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else if (_batchId != null)
            AppFormDropdown<int>(
              key: const Key('field-section'),
              label: 'Section',
              value: _sectionId,
              items: _sectionsForBatch
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
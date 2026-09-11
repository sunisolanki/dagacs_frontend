import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/program.dart';
import '../../models/semester.dart';
import '../../models/subject.dart';
import '../../models/subject_offering.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [SubjectOffering].
///
/// Only two foreign identities are collected, matching the backend request
/// contract: the Subject and the Semester. The Semester dropdown shows the
/// full academic context (session — program — department — semester) so
/// same-named semesters in different programs stay distinguishable.
Future<SubjectOffering?> showSubjectOfferingForm(
  BuildContext context,
  MasterDataRepository repository, {
  SubjectOffering? initial,
}) {
  return showDialog<SubjectOffering>(
    context: context,
    builder: (_) => _SubjectOfferingFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _SubjectOfferingFormDialog extends StatefulWidget {
  const _SubjectOfferingFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final SubjectOffering? initial;

  @override
  State<_SubjectOfferingFormDialog> createState() =>
      _SubjectOfferingFormDialogState();
}

class _SubjectOfferingFormDialogState
    extends State<_SubjectOfferingFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _subjectId;
  int? _semesterId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Semester> _semesters = const [];
  List<Subject> _subjects = const [];
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
        widget.repository.getSemesters(),
        widget.repository.getSubjects(),
        widget.repository.getAcademicSessions(),
        widget.repository.getPrograms(),
      ]);
      if (!mounted) return;
      final semesters = results[0] as List<Semester>;
      final subjects = results[1] as List<Subject>;
      final sessions = results[2] as List<AcademicSession>;
      final programs = results[3] as List<Program>;
      setState(() {
        _semesters = semesters;
        _subjects = subjects;
        _sessionsById = {
          for (final session in sessions)
            if (session.id != null) session.id!: session,
        };
        _programsById = {
          for (final program in programs)
            if (program.id != null) program.id!: program,
        };
        _subjectId = widget.initial?.subjectId ?? _subjects.firstOrNull?.id;
        _semesterId = widget.initial?.semesterId ?? _semesters.firstOrNull?.id;
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

  String _semesterLabel(Semester s) {
    final shallow = s.academicSession;
    if (shallow == null) {
      return s.name?.trim().isNotEmpty == true
          ? s.name!
          : 'Semester unavailable';
    }
    final session = _sessionsById[shallow.id] ?? shallow;
    final contextLabel =
        academicSessionContextLabel(session, programsById: _programsById);
    final name = s.name?.trim();
    return name == null || name.isEmpty
        ? contextLabel
        : '$contextLabel — $name';
  }

  String _subjectLabel(Subject s) {
    final code = s.code?.trim();
    final name = s.name?.trim();
    if (code == null || code.isEmpty) {
      return name?.isNotEmpty == true ? name! : 'Subject unavailable';
    }
    if (name == null || name.isEmpty) return code;
    return '$code — $name';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = SubjectOfferingRequest(
      subjectId: _subjectId!,
      semesterId: _semesterId!,
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateSubjectOffering(widget.initial!.id!, request)
          : await widget.repository.createSubjectOffering(request);
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
          child:
              AppLoadingState(message: 'Loading reference data...'));
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
            _isEdit ? 'Edit Subject Offering' : 'Add Subject Offering',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppFormDropdown<int>(
            key: const Key('field-subject'),
            label: 'Subject',
            value: _subjectId,
            items: _subjects
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        _subjectLabel(s),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _subjectId = v),
            validator: (v) => v == null ? 'Subject is required' : null,
          ),
          const SizedBox(height: 12),
          AppFormDropdown<int>(
            key: const Key('field-semester'),
            label: 'Semester',
            value: _semesterId,
            items: _semesters
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        _semesterLabel(s),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _semesterId = v),
            validator: (v) => v == null ? 'Semester is required' : null,
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
            submitKey: 'submit-subject-offering',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}
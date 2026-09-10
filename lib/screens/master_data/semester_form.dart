import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/semester.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Semester]. Academic sessions are loaded
/// from the live repository for the required parent dropdown.
Future<Semester?> showSemesterForm(
  BuildContext context,
  MasterDataRepository repository, {
  Semester? initial,
}) {
  return showDialog<Semester>(
    context: context,
    builder: (_) => _SemesterFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _SemesterFormDialog extends StatefulWidget {
  const _SemesterFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final Semester? initial;

  @override
  State<_SemesterFormDialog> createState() => _SemesterFormDialogState();
}

class _SemesterFormDialogState extends State<_SemesterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _year =
      TextEditingController(text: widget.initial?.year?.toString() ?? '');

  int? _academicSessionId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<AcademicSession> _sessions = const [];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final sessions = await widget.repository.getAcademicSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _academicSessionId = widget.initial?.academicSession?.id ??
            widget.initial?.academicSessionId ??
            sessions.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Academic Session reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Academic Session reference data.';
        _loadingReferences = false;
      });
    }
  }

  String? _yearValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Year is required';
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Year must be a number';
    if (parsed < 2000 || parsed > 2100) return 'Enter a valid year';
    return null;
  }

  String _sessionLabel(AcademicSession s) {
    final programName = s.program?.name;
    final sessionName = s.name ?? 'Unknown';
    if (programName == null || programName.isEmpty) return sessionName;
    return '$sessionName — $programName';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = SemesterRequest(
      name: _name.text.trim(),
      code: _code.text.trim(),
      year: int.parse(_year.text.trim()),
      academicSessionId: _academicSessionId!,
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateSemester(widget.initial!.id!, request)
          : await widget.repository.createSemester(request);
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
          child: AppLoadingState(
              message: 'Loading Academic Session reference data...'));
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
            _isEdit ? 'Edit Semester' : 'Add Semester',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppFormTextField(
            key: const Key('field-name'),
            label: 'Name',
            controller: _name,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          AppFormTextField(
            key: const Key('field-code'),
            label: 'Code',
            controller: _code,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Code is required' : null,
          ),
          AppFormTextField(
            key: const Key('field-year'),
            label: 'Year (e.g. 2026)',
            controller: _year,
            keyboardType: TextInputType.number,
            validator: _yearValidator,
          ),
          AppFormDropdown<int>(
            key: const Key('field-academic-session'),
            label: 'Academic Session',
            value: _academicSessionId,
            items: _sessions
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(_sessionLabel(s)),
                ))
                .toList(),
            onChanged: (v) => setState(() => _academicSessionId = v),
            validator: (v) => v == null ? 'Academic Session is required' : null,
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
            submitKey: 'submit-semester',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}
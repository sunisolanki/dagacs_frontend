import 'package:flutter/material.dart';

import '../../models/department.dart';
import '../../models/program.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Program]. Departments are loaded from
/// the live repository for the required parent dropdown.
Future<Program?> showProgramForm(
  BuildContext context,
  MasterDataRepository repository, {
  Program? initial,
}) {
  return showDialog<Program>(
    context: context,
    builder: (_) => _ProgramFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _ProgramFormDialog extends StatefulWidget {
  const _ProgramFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final Program? initial;

  @override
  State<_ProgramFormDialog> createState() => _ProgramFormDialogState();
}

class _ProgramFormDialogState extends State<_ProgramFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _duration =
      TextEditingController(text: widget.initial?.duration ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');

  int? _departmentId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Department> _departments = const [];

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
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final departments = await widget.repository.getDepartments();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _departmentId = widget.initial?.department?.id ??
            widget.initial?.departmentId ??
            departments.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Department reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Department reference data.';
        _loadingReferences = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = ProgramRequest(
      name: _name.text.trim(),
      code: _code.text.trim(),
      duration: _duration.text.trim(),
      departmentId: _departmentId!,
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateProgram(widget.initial!.id!, request)
          : await widget.repository.createProgram(request);
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
              message: 'Loading Department reference data...'));
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
            _isEdit ? 'Edit Program' : 'Add Program',
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
            key: const Key('field-duration'),
            label: 'Duration',
            controller: _duration,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Duration is required'
                : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-department'),
            label: 'Department',
            value: _departmentId,
            items: _departments
                .where((d) => d.id != null)
                .map((d) => DropdownMenuItem(
                    value: d.id, child: Text(d.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _departmentId = v),
            validator: (v) => v == null ? 'Department is required' : null,
          ),
          AppFormTextField(
            key: const Key('field-description'),
            label: 'Description (optional)',
            controller: _description,
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
            submitKey: 'submit-program',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}
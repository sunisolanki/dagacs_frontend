import 'package:flutter/material.dart';

import '../../models/department.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Department]. Returns the created or
/// updated [Department], or null when cancelled.
Future<Department?> showDepartmentForm(
  BuildContext context,
  MasterDataRepository repository, {
  Department? initial,
}) {
  return showDialog<Department>(
    context: context,
    builder: (_) => _DepartmentFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _DepartmentFormDialog extends StatefulWidget {
  const _DepartmentFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final Department? initial;

  @override
  State<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<_DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');

  bool _submitting = false;
  String? _submitError;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = DepartmentRequest(
      name: _name.text.trim(),
      code: _code.text.trim(),
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
              .updateDepartment(widget.initial!.id!, request)
          : await widget.repository.createDepartment(request);
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
    return AppDialogFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit Department' : 'Add Department',
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
              submitKey: 'submit-department',
              submitLabel: _isEdit ? 'Save Changes' : 'Create',
            ),
          ],
        ),
      ),
    );
  }
}
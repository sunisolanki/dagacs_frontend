import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Subject].
Future<Subject?> showSubjectForm(
  BuildContext context,
  MasterDataRepository repository, {
  Subject? initial,
}) {
  return showDialog<Subject>(
    context: context,
    builder: (_) => _SubjectFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _SubjectFormDialog extends StatefulWidget {
  const _SubjectFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final Subject? initial;

  @override
  State<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<_SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');
  late final TextEditingController _creditHours =
      TextEditingController(text: widget.initial?.creditHours ?? '');
  late final TextEditingController _department =
      TextEditingController(text: widget.initial?.department ?? '');

  String? _status;

  bool _submitting = false;
  String? _submitError;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _status = widget.initial?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _creditHours.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = SubjectRequest(
      code: _code.text.trim(),
      name: _name.text.trim(),
      creditHours: _creditHours.text.trim(),
      status: _status ?? 'ACTIVE',
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      department:
          _department.text.trim().isEmpty ? null : _department.text.trim(),
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateSubject(widget.initial!.id!, request)
          : await widget.repository.createSubject(request);
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
              _isEdit ? 'Edit Subject' : 'Add Subject',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            AppFormTextField(
              key: const Key('field-code'),
              label: 'Code',
              controller: _code,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Code is required' : null,
            ),
            AppFormTextField(
              key: const Key('field-name'),
              label: 'Name',
              controller: _name,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            AppFormTextField(
              key: const Key('field-creditHours'),
              label: 'Credit Hours',
              controller: _creditHours,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Credit hours is required'
                  : null,
            ),
            AppFormTextField(
              key: const Key('field-department'),
              label: 'Department (optional)',
              controller: _department,
            ),
            AppFormTextField(
              key: const Key('field-description'),
              label: 'Description (optional)',
              controller: _description,
            ),
            AppFormDropdown<String>(
              key: const Key('field-status'),
              label: 'Status',
              value: _status ?? 'ACTIVE',
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
              ],
              onChanged: (v) => setState(() => _status = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Status is required' : null,
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
              submitKey: 'submit-subject',
              submitLabel: _isEdit ? 'Save Changes' : 'Create',
            ),
          ],
        ),
      ),
    );
  }
}
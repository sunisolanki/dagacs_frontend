import 'package:flutter/material.dart';

import '../../models/department.dart';
import '../../models/subject.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Subject]. Departments are loaded from
/// the live repository for the required parent dropdown.
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
  static final RegExp _creditHoursPattern = RegExp(r'^\d+(\.\d+)?$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');
  late final TextEditingController _creditHours =
      TextEditingController(text: widget.initial?.creditHours ?? '');

  String? _status;
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
    _status = widget.initial?.status ?? 'ACTIVE';
    _departmentId =
        widget.initial?.department?.id ?? widget.initial?.departmentId;
    _loadReferences();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _creditHours.dispose();
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

  String? _creditHoursValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Credit hours is required';
    final value = v.trim();
    if (!_creditHoursPattern.hasMatch(value)) {
      return 'Credit hours must be a positive number';
    }
    if (double.parse(value) <= 0) {
      return 'Credit hours must be a positive number';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departmentId == null) return;
    final request = SubjectRequest(
      code: _code.text.trim(),
      name: _name.text.trim(),
      creditHours: _creditHours.text.trim(),
      departmentId: _departmentId!,
      status: _status ?? 'ACTIVE',
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
            keyboardType: TextInputType.number,
            validator: _creditHoursValidator,
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
    );
  }
}
import 'package:flutter/material.dart';

import '../../models/department.dart';
import '../../models/teacher_management.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../repositories/teacher_management_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit teacher form. Returns the saved teacher on success,
/// or null when the user cancels.
Future<TeacherManagement?> showTeacherFormDialog({
  required BuildContext context,
  required TeacherManagementRepository repository,
  required MasterDataRepository masterDataRepository,
  TeacherManagement? initial,
}) {
  return showDialog<TeacherManagement>(
    context: context,
    builder: (_) => _TeacherFormDialog(
      repository: repository,
      masterDataRepository: masterDataRepository,
      initial: initial,
    ),
  );
}

class _TeacherFormDialog extends StatefulWidget {
  const _TeacherFormDialog({
    required this.repository,
    required this.masterDataRepository,
    required this.initial,
  });

  final TeacherManagementRepository repository;
  final MasterDataRepository masterDataRepository;
  final TeacherManagement? initial;

  @override
  State<_TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends State<_TeacherFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullName =
      TextEditingController(text: widget.initial?.fullName ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.initial?.email ?? '');
  late final TextEditingController _designation =
      TextEditingController(text: widget.initial?.designation ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.initial?.phone ?? '');
  late final TextEditingController _password = TextEditingController();
  late final TextEditingController _confirmPassword = TextEditingController();

  int? _departmentId;
  String? _status;

  bool _loadingDepartments = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Department> _departments = const [];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _departmentId = widget.initial?.departmentId;
    _status = widget.initial?.status ?? 'ACTIVE';
    _loadDepartments();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _designation.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDepartments = true;
      _referencesError = null;
    });
    try {
      final departments =
          await widget.masterDataRepository.getDepartments();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _loadingDepartments = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load department reference data.';
        _loadingDepartments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load department reference data.';
        _loadingDepartments = false;
      });
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required' : null;

  String? _passwordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.trim().length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm the password';
    }
    if (value != _password.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isEdit) {
      await _submitUpdate();
    } else {
      await _submitCreate();
    }
  }

  Future<void> _submitCreate() async {
    final request = TeacherCreateRequest(
      email: _email.text.trim(),
      fullName: _fullName.text.trim(),
      designation: _designation.text.trim(),
      phone: _phone.text.trim(),
      departmentId: _departmentId,
      password: _password.text,
      status: _status,
    );

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await widget.repository.createTeacher(request);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _messageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Something went wrong while saving. Please try again.';
      });
    }
  }

  Future<void> _submitUpdate() async {
    final request = TeacherUpdateRequest(
      fullName: _fullName.text.trim(),
      phone: _phone.text.trim(),
      designation: _designation.text.trim(),
      departmentId: _departmentId,
    );

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result =
          await widget.repository.updateTeacher(widget.initial!.id!, request);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _messageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Something went wrong while saving. Please try again.';
      });
    }
  }

  String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return 'Please check the values and try again.';
      case 404:
        return 'This teacher no longer exists.';
      case 409:
        return _isEdit
            ? 'Could not save: a teacher with this email already exists, '
                'or this department already has a different HOD.'
            : 'A teacher (or student) with this email already exists.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(width: 560, child: _buildContent());
  }

  Widget _buildContent() {
    if (_loadingDepartments) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }
    if (_referencesError != null) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_referencesError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _loadDepartments, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit Teacher' : 'Add Teacher',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (!_isEdit) ...[
            AppFormTextField(
              key: const Key('field-email'),
              label: 'Email (login username)',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: _required,
            ),
          ],
          AppFormTextField(
            key: const Key('field-fullName'),
            label: 'Full Name',
            controller: _fullName,
            validator: _isEdit
                ? null
                : (v) => (v == null || v.trim().isEmpty)
                    ? 'Full name is required'
                    : null,
          ),
          AppFormTextField(
            key: const Key('field-designation'),
            label: 'Designation (optional)',
            controller: _designation,
          ),
          AppFormTextField(
            key: const Key('field-phone'),
            label: 'Phone (optional)',
            controller: _phone,
            keyboardType: TextInputType.phone,
          ),
          AppFormDropdown<int>(
            key: const Key('field-department'),
            label: 'Department (optional)',
            value: _departmentId,
            items: _departments
                .where((d) => d.id != null)
                .map((d) => DropdownMenuItem(
                    value: d.id, child: Text(d.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _departmentId = v),
          ),
          if (!_isEdit) ...[
            AppFormTextField(
              key: const Key('field-password'),
              label: 'Initial Password (min 8 characters)',
              controller: _password,
              obscureText: true,
              validator: _passwordValidator,
            ),
            AppFormTextField(
              key: const Key('field-confirmPassword'),
              label: 'Confirm Password',
              controller: _confirmPassword,
              obscureText: true,
              validator: _confirmPasswordValidator,
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
            ),
          ],
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
            submitKey: 'submit-teacher',
            submitLabel: _isEdit ? 'Save Changes' : 'Create Teacher',
          ),
        ],
      ),
    );
  }
}
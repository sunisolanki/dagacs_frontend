import 'package:flutter/material.dart';

import '../models/batch.dart';
import '../models/program.dart';
import '../models/section.dart';
import '../models/student_management.dart';
import '../network/api_exception.dart';
import '../repositories/master_data_repository.dart';
import '../repositories/student_management_repository.dart';

/// ADMIN-only Manage Students screen (M5.2).
///
/// Full student-master management: list, view, create, edit and
/// activate/deactivate. Program/Batch/Section are chosen from the live master
/// data (never hardcoded) via the existing read-only master-data repository.
/// Backend authorization is authoritative - the whole API surface is
/// ADMIN-only on the server.
class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({
    super.key,
    required this.repository,
    required this.masterDataRepository,
  });

  final StudentManagementRepository repository;
  final MasterDataRepository masterDataRepository;

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<StudentManagement> _students = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await widget.repository.getStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading students.';
        _loading = false;
      });
    }
  }

  String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'Your role does not have access to manage students. '
            'This area is ADMIN-only on the backend.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
  }

  Future<void> _openCreate() async {
    final created = await showDialog<StudentManagement>(
      context: context,
      builder: (_) => _StudentFormDialog(
        repository: widget.repository,
        masterDataRepository: widget.masterDataRepository,
        initial: null,
      ),
    );
    if (created != null) _load();
  }

  Future<void> _openEdit(StudentManagement student) async {
    final updated = await showDialog<StudentManagement>(
      context: context,
      builder: (_) => _StudentFormDialog(
        repository: widget.repository,
        masterDataRepository: widget.masterDataRepository,
        initial: student,
      ),
    );
    if (updated != null) _load();
  }

  Future<void> _openDetail(StudentManagement student) async {
    final action = await showDialog<_DetailAction>(
      context: context,
      builder: (dialogContext) => _StudentDetailDialog(
        student: student,
        onEdit: () => Navigator.of(dialogContext).pop(_DetailAction.edit),
        onToggleStatus: () =>
            Navigator.of(dialogContext).pop(_DetailAction.toggle),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _DetailAction.edit) {
      await _openEdit(student);
    } else if (action == _DetailAction.toggle) {
      await _setStatus(student, student.isActive ? 'INACTIVE' : 'ACTIVE');
    }
  }

  Future<void> _setStatus(StudentManagement student, String status) async {
    try {
      await widget.repository.setStudentStatus(student.id!, status);
      if (!mounted) return;
      await _load();
    } on ApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change status. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Students')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-student'),
        tooltip: 'Add student',
        onPressed: _openCreate,
        child: const Icon(Icons.person_add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_students.isEmpty) {
      return const Center(child: Text('No students found. Use + to add one.'));
    }
    return ListView.builder(
      key: const Key('student-list'),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            key: Key('student-tile-${student.id}'),
            leading: CircleAvatar(
              child: Text(
                _initials(student.name),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            title: Text(
              '${student.name ?? '-'}  (${student.rollNumber ?? '-'})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${student.enrollmentNumber ?? '-'} · '
              '${student.programName ?? '-'} · ${student.batchName ?? '-'} · '
              '${student.sectionName ?? '-'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBadge(status: student.status),
                IconButton(
                  key: Key('toggle-status-${student.id}'),
                  tooltip: student.isActive ? 'Deactivate' : 'Activate',
                  icon: Icon(
                    student.isActive
                        ? Icons.block
                        : Icons.check_circle_outline,
                  ),
                  onPressed: () => _setStatus(
                      student, student.isActive ? 'INACTIVE' : 'ACTIVE'),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openDetail(student),
          ),
        );
      },
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

enum _DetailAction { edit, toggle }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? Colors.green.shade800 : Colors.orange.shade900,
        ),
      ),
    );
  }
}

class _StudentDetailDialog extends StatelessWidget {
  const _StudentDetailDialog({
    required this.student,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final StudentManagement student;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String? value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey)),
            ),
            Expanded(child: Text(value ?? '-')),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Text(student.name ?? 'Student'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Roll Number', student.rollNumber),
            row('Enrollment No', student.enrollmentNumber),
            row('Email', student.email),
            row('Gender', student.gender),
            row('Father', student.fatherName),
            row('Mother', student.motherName),
            row('Age', student.age?.toString()),
            row('Admission Date', student.admissionDate),
            row('Program', student.programName),
            row('Batch', student.batchName),
            row('Section', student.sectionName),
            row('Status', student.status),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('detail-toggle-status'),
          onPressed: onToggleStatus,
          child: Text(student.isActive ? 'Deactivate' : 'Activate'),
        ),
        TextButton(
          key: const Key('edit-student'),
          onPressed: onEdit,
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class _StudentFormDialog extends StatefulWidget {
  const _StudentFormDialog({
    required this.repository,
    required this.masterDataRepository,
    required this.initial,
  });

  final StudentManagementRepository repository;
  final MasterDataRepository masterDataRepository;
  final StudentManagement? initial;

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _rollNumber;
  late final TextEditingController _name = _controller(widget.initial?.name);
  late final TextEditingController _fatherName = _controller(widget.initial?.fatherName);
  late final TextEditingController _motherName = _controller(widget.initial?.motherName);
  late final TextEditingController _enrollmentNumber = _controller(widget.initial?.enrollmentNumber);
  late final TextEditingController _age = _controller(widget.initial?.age?.toString());
  late final TextEditingController _admissionDate = _controller(widget.initial?.admissionDate);
  late final TextEditingController _photoUrl = _controller(widget.initial?.photoUrl);
  late final TextEditingController _email = _controller(widget.initial?.email);

  String? _gender;
  int? _programId;
  int? _batchId;
  int? _sectionId;
  String? _status;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Program> _programs = const [];
  List<Batch> _batches = const [];
  List<Section> _sections = const [];

  TextEditingController _controller(String? value) =>
      TextEditingController(text: value ?? '');

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _rollNumber = _controller(widget.initial?.rollNumber);
    _gender = widget.initial?.gender;
    _status = widget.initial?.status ?? 'ACTIVE';
    _loadReferences();
  }

  @override
  void dispose() {
    _rollNumber.dispose();
    _name.dispose();
    _fatherName.dispose();
    _motherName.dispose();
    _enrollmentNumber.dispose();
    _age.dispose();
    _admissionDate.dispose();
    _photoUrl.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final programs = await widget.masterDataRepository.getPrograms();
      final batches = await widget.masterDataRepository.getBatches();
      final sections = await widget.masterDataRepository.getSections();
      if (!mounted) return;
      setState(() {
        _programs = programs;
        _batches = batches;
        _sections = sections;
        _programId = widget.initial?.programId ?? programs.firstOrNull?.id;
        _batchId = widget.initial?.batchId ?? batches.firstOrNull?.id;
        _sectionId = widget.initial?.sectionId ?? sections.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError =
            'Could not load Program/Batch/Section reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError =
            'Could not load Program/Batch/Section reference data.';
        _loadingReferences = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = StudentManagementRequest(
      rollNumber: _rollNumber.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      name: _name.text.trim(),
      gender: _gender,
      fatherName: _fatherName.text.trim(),
      motherName: _motherName.text.trim(),
      photoUrl: _photoUrl.text.trim(),
      enrollmentNumber: _enrollmentNumber.text.trim(),
      age: int.tryParse(_age.text.trim()),
      admissionDate: _admissionDate.text.trim(),
      status: _status,
      programId: _programId,
      batchId: _batchId,
      sectionId: _sectionId,
    );

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateStudent(widget.initial!.id!, request)
          : await widget.repository.createStudent(request);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.statusCode == 409
            ? 'A student with this roll number or email already exists.'
            : e.message;
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
    return Dialog(
      child: SizedBox(
        width: 560,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingReferences) {
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
                    onPressed: _loadReferences, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit Student' : 'Add Student',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _fieldText(
              key: const Key('field-rollNumber'),
              label: 'Roll Number',
              controller: _rollNumber,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Roll number is required' : null,
            ),
            _fieldText(
              key: const Key('field-name'),
              label: 'Name',
              controller: _name,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            _fieldText(
                key: const Key('field-fatherName'),
                label: 'Father Name',
                controller: _fatherName),
            _fieldText(
                key: const Key('field-motherName'),
                label: 'Mother Name',
                controller: _motherName),
            _fieldText(
                key: const Key('field-enrollmentNumber'),
                label: 'Enrollment Number',
                controller: _enrollmentNumber),
            _fieldText(
              key: const Key('field-age'),
              label: 'Age',
              controller: _age,
              keyboardType: TextInputType.number,
            ),
            _fieldText(
                key: const Key('field-admissionDate'),
                label: 'Admission Date (e.g. 2026-01-01)',
                controller: _admissionDate),
            _fieldText(
                key: const Key('field-photoUrl'),
                label: 'Photo URL (optional)',
                controller: _photoUrl),
            _fieldText(
                key: const Key('field-email'),
                label: 'Email (optional)',
                controller: _email),
            DropdownButtonFormField<String>(
              key: const Key('field-gender'),
              decoration: const InputDecoration(labelText: 'Gender'),
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'F', child: Text('F')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _gender = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Gender is required' : null,
            ),
            DropdownButtonFormField<int>(
              key: const Key('field-program'),
              decoration: const InputDecoration(labelText: 'Program'),
              value: _programId,
              items: _programs
                  .where((p) => p.id != null)
                  .map((p) => DropdownMenuItem(
                      value: p.id, child: Text(p.name ?? 'Unknown')))
                  .toList(),
              onChanged: (v) => setState(() => _programId = v),
              validator: (v) => v == null ? 'Program is required' : null,
            ),
            DropdownButtonFormField<int>(
              key: const Key('field-batch'),
              decoration: const InputDecoration(labelText: 'Batch'),
              value: _batchId,
              items: _batches
                  .where((b) => b.id != null)
                  .map((b) => DropdownMenuItem(
                      value: b.id, child: Text(b.name ?? 'Unknown')))
                  .toList(),
              onChanged: (v) => setState(() => _batchId = v),
              validator: (v) => v == null ? 'Batch is required' : null,
            ),
            DropdownButtonFormField<int>(
              key: const Key('field-section'),
              decoration: const InputDecoration(labelText: 'Section'),
              value: _sectionId,
              items: _sections
                  .where((s) => s.id != null)
                  .map((s) => DropdownMenuItem(
                      value: s.id, child: Text(s.name ?? 'Unknown')))
                  .toList(),
              onChanged: (v) => setState(() => _sectionId = v),
              validator: (v) => v == null ? 'Section is required' : null,
            ),
            DropdownButtonFormField<String>(
              key: const Key('field-status'),
              decoration: const InputDecoration(labelText: 'Status'),
              value: _status ?? 'ACTIVE',
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(_submitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('submit-student'),
                  onPressed: _submitting ? null : _submit,
                  child: Text(_isEdit ? 'Save Changes' : 'Create Student'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldText({
    required Key key,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: key,
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
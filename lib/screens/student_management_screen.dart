import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/batch.dart';
import '../models/program.dart';
import '../models/section.dart';
import '../models/student_management.dart';
import '../network/api_exception.dart';
import '../repositories/master_data_repository.dart';
import '../repositories/student_management_repository.dart';
import '../widgets/dagacs_widgets.dart';

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

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  /// Client-side, case-insensitive search over the already-loaded student list
  /// (name, roll number, enrollment number). The full dataset is in memory, so
  /// no per-keystroke API call is made and no debounce is needed. An empty
  /// (or whitespace-only) query restores the complete list.
  List<StudentManagement> get _visibleStudents {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students.where((s) {
      final name = s.name?.toLowerCase() ?? '';
      final rollNumber = s.rollNumber?.toLowerCase() ?? '';
      final enrollmentNumber = s.enrollmentNumber?.toLowerCase() ?? '';
      return name.contains(query) ||
          rollNumber.contains(query) ||
          enrollmentNumber.contains(query);
    }).toList();
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
      return const AppLoadingState(message: 'Loading students...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_students.isEmpty) {
      return const AppEmptyState(
        icon: Icons.person_off_outlined,
        message: 'No students found. Use + to add one.',
      );
    }
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildStudentList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        DagacsSpace.sm,
        DagacsSpace.lg,
        DagacsSpace.sm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: TextField(
          key: const Key('student-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search by name, roll number, or enrollment number',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    key: const Key('student-search-clear'),
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
            filled: true,
            fillColor: DagacsColors.surfaceAlt,
            border: const OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius:
                  BorderRadius.all(Radius.circular(DagacsRadius.md)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    final visible = _visibleStudents;
    if (visible.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off,
        message: 'No students match',
      );
    }
    return ListView.builder(
      key: const Key('student-list'),
      padding: EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        0,
        DagacsSpace.lg,
        96,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final student = visible[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DagacsSpace.sm + 2),
          child: AppCard(
            key: Key('student-tile-${student.id}'),
            onTap: () => _openDetail(student),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            child: Row(
              children: [
                AppAvatar(name: student.name, size: 44),
                const SizedBox(width: DagacsSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student.name ?? '-'}  (${student.rollNumber ?? '-'})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student.enrollmentNumber ?? '-'} · '
                        '${student.programName ?? '-'} · '
                        '${student.batchName ?? '-'} · '
                        '${student.sectionName ?? '-'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DagacsSpace.sm),
                AppStatusBadge(
                  label: student.status ?? '-',
                  active: student.status == 'ACTIVE',
                ),
                const SizedBox(width: 2),
                IconButton(
                  key: Key('toggle-status-${student.id}'),
                  tooltip: student.isActive ? 'Deactivate' : 'Activate',
                  icon: Icon(
                    student.isActive
                        ? Icons.block
                        : Icons.check_circle_outline,
                    color: student.isActive
                        ? DagacsColors.error
                        : DagacsColors.success,
                  ),
                  onPressed: () => _setStatus(
                      student, student.isActive ? 'INACTIVE' : 'ACTIVE'),
                ),
                Icon(Icons.chevron_right, color: DagacsColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _DetailAction { edit, toggle }

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
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: DagacsColors.textSecondary,
                ),
              ),
            ),
            Expanded(child: Text(value ?? '-')),
          ],
        ),
      );
    }

    return AppDialogFrame(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: student.name, size: 44),
              const SizedBox(width: DagacsSpace.lg),
              Expanded(
                child: Text(
                  student.name ?? 'Student',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
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
          const SizedBox(height: DagacsSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const Key('detail-toggle-status'),
                onPressed: onToggleStatus,
                child: Text(student.isActive ? 'Deactivate' : 'Activate'),
              ),
              const SizedBox(width: DagacsSpace.sm),
              ElevatedButton(
                key: const Key('edit-student'),
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
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
    return AppDialogFrame(width: 560, child: _buildContent());
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
    return Form(
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
          AppFormTextField(
            key: const Key('field-rollNumber'),
            label: 'Roll Number',
            controller: _rollNumber,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Roll number is required'
                : null,
          ),
          AppFormTextField(
            key: const Key('field-name'),
            label: 'Name',
            controller: _name,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          AppFormTextField(
              key: const Key('field-fatherName'),
              label: 'Father Name',
              controller: _fatherName),
          AppFormTextField(
              key: const Key('field-motherName'),
              label: 'Mother Name',
              controller: _motherName),
          AppFormTextField(
              key: const Key('field-enrollmentNumber'),
              label: 'Enrollment Number',
              controller: _enrollmentNumber),
          AppFormTextField(
            key: const Key('field-age'),
            label: 'Age',
            controller: _age,
            keyboardType: TextInputType.number,
          ),
          AppFormTextField(
              key: const Key('field-admissionDate'),
              label: 'Admission Date (e.g. 2026-01-01)',
              controller: _admissionDate),
          AppFormTextField(
              key: const Key('field-photoUrl'),
              label: 'Photo URL (optional)',
              controller: _photoUrl),
          AppFormTextField(
              key: const Key('field-email'),
              label: 'Email (optional)',
              controller: _email),
          AppFormDropdown<String>(
            key: const Key('field-gender'),
            label: 'Gender',
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
          AppFormDropdown<int>(
            key: const Key('field-program'),
            label: 'Program',
            value: _programId,
            items: _programs
                .where((p) => p.id != null)
                .map((p) => DropdownMenuItem(
                    value: p.id, child: Text(p.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _programId = v),
            validator: (v) => v == null ? 'Program is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-batch'),
            label: 'Batch',
            value: _batchId,
            items: _batches
                .where((b) => b.id != null)
                .map((b) => DropdownMenuItem(
                    value: b.id, child: Text(b.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _batchId = v),
            validator: (v) => v == null ? 'Batch is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-section'),
            label: 'Section',
            value: _sectionId,
            items: _sections
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                    value: s.id, child: Text(s.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _sectionId = v),
            validator: (v) => v == null ? 'Section is required' : null,
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
            submitKey: 'submit-student',
            submitLabel: _isEdit ? 'Save Changes' : 'Create Student',
          ),
        ],
      ),
    );
  }
}
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/batch.dart';
import '../models/program.dart';
import '../models/section.dart';
import '../models/student_management.dart';
import '../network/api_exception.dart';
import '../repositories/master_data_repository.dart';
import '../repositories/student_management_repository.dart';
import '../services/report_file_downloader.dart';
import '../widgets/dagacs_widgets.dart';

/// A file the admin selected for bulk import (name + in-memory bytes).
///
/// Extracted behind this tiny value type so widget tests can inject a fake
/// picker and so the real file_picker dependency stays isolated in this file.
class PickedImportFile {
  const PickedImportFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

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
    this.pickImportFile,
  });

  final StudentManagementRepository repository;
  final MasterDataRepository masterDataRepository;

  /// M9.10 import file picker; defaults to the real file_picker-backed flow.
  /// Injectable so widget tests can drive import deterministically.
  final Future<PickedImportFile?> Function()? pickImportFile;

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
    final identityMessage = messageForIdentityCode(e.code);
    if (identityMessage != null) return identityMessage;
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
    final action = await showDialog<_StudentDetailAction>(
      context: context,
      builder: (dialogContext) => _StudentDetailDialog(
        student: student,
        onEdit: () => Navigator.of(dialogContext).pop(_StudentDetailAction.edit),
        onToggleStatus: () =>
            Navigator.of(dialogContext).pop(_StudentDetailAction.toggle),
        onCreateLogin: () =>
            Navigator.of(dialogContext).pop(_StudentDetailAction.createLogin),
        onResetPassword: () =>
            Navigator.of(dialogContext).pop(_StudentDetailAction.resetPassword),
        onToggleLogin: () =>
            Navigator.of(dialogContext).pop(_StudentDetailAction.toggleLogin),
        onDownloadCredentials: () =>
            Navigator.of(dialogContext).pop(_StudentDetailAction.downloadCredentials),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _StudentDetailAction.edit) {
      await _openEdit(student);
    } else if (action == _StudentDetailAction.toggle) {
      await _setStatus(student, student.isActive ? 'INACTIVE' : 'ACTIVE');
    } else if (action == _StudentDetailAction.createLogin) {
      await _createLogin(student);
    } else if (action == _StudentDetailAction.resetPassword) {
      await _resetPassword(student);
    } else if (action == _StudentDetailAction.toggleLogin) {
      await _setLoginStatus(
          student, student.loginIsActive ? 'INACTIVE' : 'ACTIVE');
    } else if (action == _StudentDetailAction.downloadCredentials) {
      await _downloadCredentials(student);
    }
  }

  Future<void> _showError(String message) {
    if (!mounted) return Future.value();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    return Future.value();
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

  Future<void> _createLogin(StudentManagement student) async {
    final password = await _promptPassword(
      context: context,
      title: 'Create Login for ${student.name ?? 'Student'}',
      submitLabel: 'Create Login',
    );
    if (password == null || !mounted) return;
    try {
      await widget.repository
          .provisionLogin(student.id!, StudentLoginPasswordRequest(password));
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      await _showError(
          'Could not create the login. ${_reasonFor(e)} Please try again.');
    }
  }

  Future<void> _downloadCredentials(StudentManagement student) async {
    final downloadId = student.credentialDownloadId;
    if (downloadId == null || downloadId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No credentials available for download.')),
      );
      return;
    }
    try {
      final payload = await widget.repository.downloadCredentials(downloadId);
      if (!mounted) return;
      final status = await downloadReportFile(
          payload.bytes, payload.fileName, payload.contentType);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(status)));
    } on ApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download credentials.')),
      );
    }
  }

  Future<void> _resetPassword(StudentManagement student) async {
    final password = await _promptPassword(
      context: context,
      title: 'Reset Password for ${student.name ?? 'Student'}',
      submitLabel: 'Reset Password',
    );
    if (password == null || !mounted) return;
    try {
      await widget.repository
          .setLoginPassword(student.id!, StudentLoginPasswordRequest(password));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Password updated. Existing sessions keep working; the '
              'new password applies to future sign-ins.')));
    } on ApiException catch (e) {
      await _showError(
          'Could not reset the password. ${_reasonFor(e)} Please try again.');
    }
  }

  Future<void> _setLoginStatus(StudentManagement student, String status) async {
    try {
      await widget.repository.setLoginStatus(student.id!, status);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      await _showError(
          'Could not change the login status. ${_reasonFor(e)} Please try again.');
    }
  }

  String _reasonFor(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return 'The password must be at least 8 characters.';
      case 404:
        return 'This student no longer exists.';
      case 409:
        return 'A teacher or student with that email already has a login.';
      default:
        return e.message;
    }
  }

  Future<PickedImportFile?> _pickImportFileDefault() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return null;
    return PickedImportFile(name: file.name, bytes: file.bytes!);
  }

  Future<void> _openImport() async {
    final imported = await showDialog<bool>(
      context: context,
      builder: (_) => _StudentImportDialog(
        repository: widget.repository,
        pickFile: widget.pickImportFile ?? _pickImportFileDefault,
      ),
    );
    if (imported == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Students'),
        actions: [
          IconButton(
            key: const Key('import-students'),
            tooltip: 'Import students from Excel or CSV',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _openImport,
          ),
        ],
      ),
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
        final hasLogin = student.hasLogin;
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppStatusBadge(
                      label: student.status ?? '-',
                      active: student.status == 'ACTIVE',
                    ),
                    const SizedBox(height: 4),
                    AppStatusBadge(
                      label: hasLogin
                          ? (student.loginIsActive
                              ? 'LOGIN ACTIVE'
                              : 'LOGIN INACTIVE')
                          : 'NO LOGIN',
                      active: hasLogin && student.loginIsActive,
                    ),
                    if (student.mustChangePassword == true) ...[
                      const SizedBox(height: 4),
                      AppStatusBadge(
                        label: 'PASSWORD RESET',
                        active: false,
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: DagacsColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _StudentDetailAction { edit, toggle, createLogin, resetPassword, toggleLogin, downloadCredentials }

class _StudentDetailDialog extends StatelessWidget {
  const _StudentDetailDialog({
    required this.student,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onCreateLogin,
    required this.onResetPassword,
    required this.onToggleLogin,
    required this.onDownloadCredentials,
  });

  final StudentManagement student;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onCreateLogin;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleLogin;
  final VoidCallback onDownloadCredentials;

  bool get _hasLogin => student.hasLogin;

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
      width: 520,
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
          const Divider(height: 28),
          Text('Login Account',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          row('Linked', _hasLogin ? 'Yes' : 'No'),
          if (_hasLogin) row('Login Status', student.loginStatus),
          if (student.mustChangePassword == true) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.lock_open, size: 16, color: DagacsColors.brandPrimary),
                const SizedBox(width: DagacsSpace.sm),
                Text(
                  'Must change password on first login',
                  style: TextStyle(
                    color: DagacsColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          if (student.temporaryPassword != null && student.temporaryPassword!.isNotEmpty) ...[
            const Divider(height: 28),
            Text('Temporary Credentials',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            row('Temporary Password', student.temporaryPassword),
          ],
          if (student.credentialDownloadId != null && student.credentialDownloadId!.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('detail-download-credentials'),
              onPressed: onDownloadCredentials,
              child: const Text('Download Credentials (XLSX)'),
            ),
          ],
          const SizedBox(height: DagacsSpace.sm),
          Wrap(
            spacing: DagacsSpace.sm,
            runSpacing: DagacsSpace.sm,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                key: const Key('detail-toggle-status'),
                onPressed: onToggleStatus,
                child: Text(student.isActive ? 'Deactivate' : 'Activate'),
              ),
              if (!_hasLogin)
                ElevatedButton(
                  key: const Key('detail-create-login'),
                  onPressed: onCreateLogin,
                  child: const Text('Create Login'),
                )
              else ...[
                OutlinedButton(
                  key: const Key('detail-reset-password'),
                  onPressed: onResetPassword,
                  child: const Text('Reset Password'),
                ),
                OutlinedButton(
                  key: const Key('detail-toggle-login'),
                  onPressed: onToggleLogin,
                  child: Text(student.loginIsActive
                      ? 'Deactivate Login'
                      : 'Activate Login'),
                ),
              ],
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

/// Password entry dialog used for both create-login and password reset.
Future<String?> _promptPassword({
  required BuildContext context,
  required String title,
  required String submitLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _StudentPasswordDialog(
      title: title,
      submitLabel: submitLabel,
    ),
  );
}

class _StudentPasswordDialog extends StatefulWidget {
  const _StudentPasswordDialog({required this.title, required this.submitLabel});

  final String title;
  final String submitLabel;

  @override
  State<_StudentPasswordDialog> createState() => _StudentPasswordDialogState();
}

class _StudentPasswordDialogState extends State<_StudentPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.trim().length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm the password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppFormTextField(
              key: const Key('field-login-password'),
              label: 'New Password',
              controller: _passwordController,
              obscureText: _obscure,
              validator: _validatePassword,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            AppFormTextField(
              key: const Key('field-login-confirm'),
              label: 'Confirm Password',
              controller: _confirmController,
              obscureText: _obscure,
              validator: _validateConfirm,
            ),
            const SizedBox(height: 8),
            AppFormActions(
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.of(context).pop(_passwordController.text);
              },
              submitting: false,
              submitKey: 'submit-login-password',
              submitLabel: widget.submitLabel,
            ),
          ],
        ),
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

  /// Batches whose legacy program-name snapshot matches the selected program.
  ///
  /// Note: `BatchDTO` exposes only the legacy `program` name string, not a
  /// relational program id, so client-side filtering relies on that snapshot.
  /// The backend remains authoritative via Batch -> AcademicSession -> Program.
  List<Batch> _batchesForProgram(int? programId) {
    final programName = _programs
        .where((p) => p.id == programId)
        .map((p) => p.name)
        .firstOrNull;
    if (programName == null) return const [];
    return _batches.where((b) => b.program == programName).toList();
  }

  List<Section> _sectionsForBatch(int? batchId) {
    if (batchId == null) return const [];
    return _sections.where((s) => s.batchId == batchId).toList();
  }

  /// Keeps the edit-mode pre-selection only when it belongs to the selected
  /// program; otherwise falls back to the first consistent batch.
  int? _resolveBatchId(int? preferred, int? programId) {
    final matches = _batchesForProgram(programId);
    if (preferred != null && matches.any((b) => b.id == preferred)) {
      return preferred;
    }
    return matches.firstOrNull?.id;
  }

  /// Keeps the edit-mode pre-selection only when it belongs to the selected
  /// batch; otherwise falls back to the first consistent section.
  int? _resolveSectionId(int? preferred, int? batchId) {
    final matches = _sectionsForBatch(batchId);
    if (preferred != null && matches.any((s) => s.id == preferred)) {
      return preferred;
    }
    return matches.firstOrNull?.id;
  }

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
        _batchId = _resolveBatchId(widget.initial?.batchId, _programId);
        _sectionId = _resolveSectionId(widget.initial?.sectionId, _batchId);
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
            onChanged: (v) => setState(() {
              _programId = v;
              _batchId = _batchesForProgram(v).firstOrNull?.id;
              _sectionId = _sectionsForBatch(_batchId).firstOrNull?.id;
            }),
            validator: (v) => v == null ? 'Program is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-batch'),
            label: 'Batch',
            value: _batchId,
            items: _batchesForProgram(_programId)
                .where((b) => b.id != null)
                .map((b) => DropdownMenuItem(
                    value: b.id, child: Text(b.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() {
              _batchId = v;
              _sectionId = _sectionsForBatch(v).firstOrNull?.id;
            }),
            validator: (v) => v == null ? 'Batch is required' : null,
          ),
          if (_sectionsForBatch(_batchId).isNotEmpty)
            AppFormDropdown<int>(
              key: const Key('field-section'),
              label: 'Section',
              value: _sectionId,
              items: _sectionsForBatch(_batchId)
                  .where((s) => s.id != null)
                  .map((s) => DropdownMenuItem(
                      value: s.id, child: Text(s.name ?? 'Unknown')))
                  .toList(),
              onChanged: (v) => setState(() => _sectionId = v),
              validator: (v) => v == null ? 'Section is required' : null,
            )
          else if (_batchId != null)
            Container(
              key: const Key('no-sections-note'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: DagacsColors.infoBg,
                borderRadius:
                    const BorderRadius.all(Radius.circular(DagacsRadius.md)),
              ),
              child: const Text(
                'This batch has no sections. The student is added without a '
                'section.',
                style: TextStyle(fontSize: 13, color: DagacsColors.info),
              ),
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

/// M9.10 bulk import dialog (ADMIN): choose an .xlsx/.csv file, upload it and
/// render the all-or-nothing summary returned by the backend. On a clean import
/// it pops with {@code true} so the screen refreshes the student list; on a
/// rejected import the row errors are shown and nothing has been persisted.
class _StudentImportDialog extends StatefulWidget {
  const _StudentImportDialog({
    required this.repository,
    required this.pickFile,
  });

  final StudentManagementRepository repository;
  final Future<PickedImportFile?> Function() pickFile;

  @override
  State<_StudentImportDialog> createState() => _StudentImportDialogState();
}

class _StudentImportDialogState extends State<_StudentImportDialog> {
  PickedImportFile? _file;
  bool _submitting = false;
  String? _error;
  StudentImportResult? _result;

  Future<void> _chooseFile() async {
    setState(() {
      _error = null;
      _result = null;
    });
    try {
      final picked = await widget.pickFile();
      if (picked == null || !mounted) return;
      setState(() => _file = picked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the file picker. Please try again.');
    }
  }

  Future<void> _import() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.repository.importStudents(
        filename: file.name,
        bytes: file.bytes,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _importErrorFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong while importing. Please try again.';
      });
    }
  }

  String _importErrorFor(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return e.message;
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'Your role does not have access to import students. '
            'This area is ADMIN-only on the backend.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      width: 560,
      child: _result != null
          ? _buildSummary()
          : _buildEntry(),
    );
  }

  Widget _buildEntry() {
    final hasFile = _file != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Import Students', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Upload an Excel (.xlsx) or CSV (.csv) file with the columns: '
          'Roll Number, Email, Name, Gender, Father Name, Mother Name, '
          'Photo URL, Enrollment Number, Age, Admission Date, Status, '
          'Program ID, Batch ID, Section ID (leave Section ID blank for a '
          'batch that has no sections). Import is all-or-nothing: if '
          'any row is invalid, no students are added.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('pick-import-file'),
          onPressed: _chooseFile,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Choose File'),
        ),
        if (hasFile) ...[
          const SizedBox(height: 8),
          Text(
            _file!.name,
            key: const Key('import-file-name'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const Key('import-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: DagacsSpace.sm),
            ElevatedButton(
              key: const Key('submit-import'),
              onPressed: _submitting || !hasFile ? null : _import,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Import'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final result = _result!;
    final success = result.isSuccess;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          success ? 'Import Complete' : 'Import Failed',
          key: const Key('import-summary-title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          success
              ? 'Imported ${result.importedRows} of ${result.totalRows} students.'
              : 'No students were imported (${result.rejectedRows} row(s) '
                  'rejected). Please fix the errors below and re-upload.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _summaryChip('Total rows', result.totalRows),
            const SizedBox(width: DagacsSpace.sm),
            _summaryChip('Imported', result.importedRows),
            const SizedBox(width: DagacsSpace.sm),
            _summaryChip('Rejected', result.rejectedRows),
          ],
        ),
        if (!success && result.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Row errors',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (int index = 0; index < result.errors.length; index++) ...[
            if (index > 0) const SizedBox(height: 4),
            _buildErrorRow(result.errors[index], index),
          ],
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            key: const Key('import-done'),
            onPressed: () => Navigator.of(context).pop(success),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, int value) {
    return Expanded(
      child: Container(
        key: Key('import-chip-$label'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: DagacsColors.surfaceAlt,
          borderRadius: const BorderRadius.all(Radius.circular(DagacsRadius.md)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRow(StudentImportError error, int index) {
    final field = error.field ?? 'row';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            'Row ${error.rowNumber}:',
            key: Key('import-error-row-$index'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text('$field - ${error.message ?? 'Invalid row'}'),
        ),
      ],
    );
  }
}
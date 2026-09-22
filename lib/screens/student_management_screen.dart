import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/academic_session.dart';
import '../models/batch.dart';
import '../models/program.dart';
import '../models/section.dart';
import '../models/semester.dart';
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
  StudentPage _page = const StudentPage();
  bool _loading = true;
  bool _initialLoading = true;
  String? _error;

  final _searchController = TextEditingController();
  Timer? _debounce;

  StudentFilterOptionsData _filterOptions = const StudentFilterOptionsData();
  int? _academicSessionId;
  int? _programId;
  int? _semesterId;
  int? _batchId;
  int? _sectionId;
  String? _status;
  String? _loginStatus;
  int _pageIndex = 0;

  int _pageSeq = 0;
  int _filtersSeq = 0;

  bool get _hasActiveFilters =>
      _academicSessionId != null ||
      _programId != null ||
      _semesterId != null ||
      _batchId != null ||
      _sectionId != null ||
      _status != null ||
      _loginStatus != null ||
      _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Reloads the first page (used by create/edit/status/login/import flows).
  Future<void> _load() => _loadPage(reset: true);

  /// Server-side search + filter + pagination. [reset] goes back to page 0.
  Future<void> _loadPage({bool reset = false}) async {
    final seq = ++_pageSeq;
    final pageIndex = reset ? 0 : _pageIndex;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _pageIndex = 0;
    });
    try {
      final searchText = _searchController.text.trim();
      final result = await widget.repository.searchStudents(StudentSearchQuery(
        search: searchText.isEmpty ? null : searchText,
        academicSessionId: _academicSessionId,
        programId: _programId,
        semesterId: _semesterId,
        batchId: _batchId,
        sectionId: _sectionId,
        status: _status,
        loginStatus: _loginStatus,
        page: pageIndex,
        size: 20,
      ));
      if (!mounted || seq != _pageSeq) return;
      setState(() {
        _page = result;
        _pageIndex = result.page;
        _loading = false;
        _initialLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _pageSeq) return;
      setState(() {
        _error = _messageFor(e);
        _loading = false;
        _initialLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _pageSeq) return;
      setState(() {
        _error = 'Something went wrong while loading students.';
        _loading = false;
        _initialLoading = false;
      });
    }
  }

  /// Fetches the cascaded master-data filter options for the CURRENT selection
  /// (options are master-data sourced, so they remain available with zero
  /// matching students). Runs alongside the page load; loses races to itself.
  Future<void> _refreshFilterOptions() async {
    final seq = ++_filtersSeq;
    try {
      final options = await widget.repository.getFilterOptions(
        academicSessionId: _academicSessionId,
        programId: _programId,
        semesterId: _semesterId,
        batchId: _batchId,
        sectionId: _sectionId,
      );
      if (!mounted || seq != _filtersSeq) return;
      setState(() => _filterOptions = options);
    } on ApiException {
      // Options are best-effort: the list/search still work without them.
    } catch (_) {
      // Ignore unexpected option-load failures for the same reason.
    }
  }

  void _goToPage(int page) {
    _pageIndex = page;
    _loadPage();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadPage(reset: true);
    });
  }

  /// Academic Session changes clear every downstream lock (Program, Semester,
  /// Batch, Section) exactly on the approved dependency chain, then re-scope
  /// the cascaded options and reload from page 0.
  void _onAcademicSessionChanged(int? value) {
    setState(() {
      _academicSessionId = value;
      _programId = null;
      _semesterId = null;
      _batchId = null;
      _sectionId = null;
    });
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  void _onProgramChanged(int? value) {
    setState(() {
      _programId = value;
      _semesterId = null;
      _batchId = null;
      _sectionId = null;
    });
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  void _onSemesterChanged(int? value) {
    setState(() {
      _semesterId = value;
      _batchId = null;
      _sectionId = null;
    });
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  void _onBatchChanged(int? value) {
    setState(() {
      _batchId = value;
      _sectionId = null;
    });
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  void _onSectionChanged(int? value) {
    setState(() => _sectionId = value);
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  void _onStatusChanged(String? value) {
    setState(() => _status = value);
    _loadPage(reset: true);
  }

  void _onLoginStatusChanged(String? value) {
    setState(() => _loginStatus = value);
    _loadPage(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _academicSessionId = null;
      _programId = null;
      _semesterId = null;
      _batchId = null;
      _sectionId = null;
      _status = null;
      _loginStatus = null;
      _searchController.clear();
    });
    _refreshFilterOptions();
    _loadPage(reset: true);
  }

  Future<void> _openFilterDialog() async {
    final selection = await showDialog<_StudentFilterSelection>(
      context: context,
      builder: (_) => _StudentFiltersDialog(
        repository: widget.repository,
        options: _filterOptions,
        academicSessionId: _academicSessionId,
        programId: _programId,
        semesterId: _semesterId,
        batchId: _batchId,
        sectionId: _sectionId,
        status: _status,
        loginStatus: _loginStatus,
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _academicSessionId = selection.academicSessionId;
      _programId = selection.programId;
      _semesterId = selection.semesterId;
      _batchId = selection.batchId;
      _sectionId = selection.sectionId;
      _status = selection.status;
      _loginStatus = selection.loginStatus;
    });
    _refreshFilterOptions();
    _loadPage(reset: true);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CreateLoginConfirmDialog(
        studentName: student.name ?? 'Student',
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await widget.repository.provisionLogin(student.id!);
      if (!mounted) return;
      await _load();
      await showDialog<void>(
        context: context,
        builder: (_) => _TemporaryCredentialsDialog(student: result),
      );
    } on ApiException catch (e) {
      await _showError(
          'Could not create the login. ${_reasonForCreateLogin(e)} Please try again.');
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

  /// Error wording for the Create Login path. The admin no longer types a
  /// password, so a backend 400 reflects a missing Student email - the
  /// backend's own meaningful message is surfaced verbatim.
  String _reasonForCreateLogin(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return e.message.isNotEmpty
            ? e.message
            : 'This student has no email to link a login to.';
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
    if (_initialLoading) {
      return const AppLoadingState(message: 'Loading students...');
    }
    if (_error != null && _page.content.isEmpty) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    return Column(
      children: [
        _buildSearchArea(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading students...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_page.content.isEmpty) {
      return _hasActiveFilters
          ? const AppEmptyState(
              icon: Icons.search_off,
              message: 'No students match the current filters.',
            )
          : const AppEmptyState(
              icon: Icons.person_off_outlined,
              message: 'No students found. Use + to add one.',
            );
    }
    return Column(
      children: [
        Expanded(child: _buildStudentList()),
        _buildPagination(),
      ],
    );
  }

  /// Responsive filter row: the full search + dropdown bar on desktop, the
  /// search field plus a Filters button (dialog/bottom-sheet style) on narrow
  /// screens.
  Widget _buildSearchArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < DagacsBreakpoints.narrow;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DagacsSpace.lg,
            DagacsSpace.sm,
            DagacsSpace.lg,
            DagacsSpace.sm,
          ),
          child: compact ? _buildCompactSearchRow() : _buildDesktopSearchBar(),
        );
      },
    );
  }

  Widget _buildCompactSearchRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _searchField()),
        const SizedBox(width: DagacsSpace.sm),
        OutlinedButton.icon(
          key: const Key('student-filters-button'),
          onPressed: _openFilterDialog,
          icon: const Icon(Icons.filter_list),
          label: const Text('Filters'),
        ),
      ],
    );
  }

  Widget _buildDesktopSearchBar() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(),
          const SizedBox(height: DagacsSpace.sm),
          Wrap(
            spacing: DagacsSpace.sm,
            runSpacing: DagacsSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _intFilterField(
                key: const Key('filter-academic-session'),
                label: 'Academic Session',
                value: _academicSessionId,
                options: _filterOptions.academicSessions,
                onChanged: _onAcademicSessionChanged,
              ),
              _intFilterField(
                key: const Key('filter-program'),
                label: 'Program',
                value: _programId,
                options: _filterOptions.programs,
                onChanged: _onProgramChanged,
              ),
              _intFilterField(
                key: const Key('filter-semester'),
                label: 'Semester',
                value: _semesterId,
                options: _filterOptions.semesters,
                onChanged: _onSemesterChanged,
              ),
              _intFilterField(
                key: const Key('filter-batch'),
                label: 'Batch',
                value: _batchId,
                options: _filterOptions.batches,
                onChanged: _onBatchChanged,
              ),
              _intFilterField(
                key: const Key('filter-section'),
                label: 'Section',
                value: _sectionId,
                options: _filterOptions.sections,
                onChanged: _onSectionChanged,
              ),
              SizedBox(
                width: 170,
                child: AppFormDropdown<String?>(
                  key: const Key('filter-status'),
                  label: 'Status',
                  value: _status,
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                    DropdownMenuItem<String?>(
                        value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem<String?>(
                        value: 'INACTIVE', child: Text('INACTIVE')),
                  ],
                  onChanged: _onStatusChanged,
                ),
              ),
              SizedBox(
                width: 200,
                child: AppFormDropdown<String?>(
                  key: const Key('filter-login-status'),
                  label: 'Login Status',
                  value: _loginStatus,
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                    DropdownMenuItem<String?>(
                        value: 'ACTIVE', child: Text('LOGIN ACTIVE')),
                    DropdownMenuItem<String?>(
                        value: 'NONE', child: Text('NO LOGIN')),
                  ],
                  onChanged: _onLoginStatusChanged,
                ),
              ),
              if (_hasActiveFilters)
                TextButton.icon(
                  key: const Key('clear-filters'),
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear Filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One master-data filter dropdown (id-based) with a leading "All" entry.
  Widget _intFilterField({
    required Key key,
    required String label,
    required int? value,
    required List<StudentFilterOption> options,
    required ValueChanged<int?> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: AppFormDropdown<int?>(
        key: key,
        label: label,
        value: value,
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('All')),
          ...options.map((o) => DropdownMenuItem<int?>(
              value: o.id,
              child: Text(o.displayName, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _searchField() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: TextField(
        key: const Key('student-search'),
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by name, roll number, or enrollment number',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('student-search-clear'),
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
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
            borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final page = _page;
    if (page.totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg, 0, DagacsSpace.lg, DagacsSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('students-prev-page'),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed:
                page.page > 0 && !_loading ? () => _goToPage(page.page - 1) : null,
          ),
          Text('Page ${page.page + 1} of ${page.totalPages}'),
          IconButton(
            key: const Key('students-next-page'),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed:
                page.hasMore && !_loading ? () => _goToPage(page.page + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    final students = _page.content;
    return ListView.builder(
      key: const Key('student-list'),
      padding: EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        0,
        DagacsSpace.lg,
        96,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
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
                        '${student.academicSessionName ?? '-'} · '
                        '${student.semesterName ?? '-'} · '
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
                      label: student.loginStatusLabel,
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

/// Immutable snapshot of the filter selection produced by the narrow-screen
/// filter dialog.
class _StudentFilterSelection {
  const _StudentFilterSelection({
    this.academicSessionId,
    this.programId,
    this.semesterId,
    this.batchId,
    this.sectionId,
    this.status,
    this.loginStatus,
  });

  final int? academicSessionId;
  final int? programId;
  final int? semesterId;
  final int? batchId;
  final int? sectionId;
  final String? status;
  final String? loginStatus;
}

/// Narrow-screen filters dialog/bottom-sheet. Holds LOCAL selection state and,
/// whenever an upstream field changes, re-fetches the master-data filter
/// options for the new selection so the dependency chain
/// (Academic Session -> Program -> Semester -> Batch -> Section) keeps working
/// inside the dialog exactly like the desktop bar. Apply returns the chosen
/// values; Clear resets all of them.
class _StudentFiltersDialog extends StatefulWidget {
  const _StudentFiltersDialog({
    required this.repository,
    required this.options,
    this.academicSessionId,
    this.programId,
    this.semesterId,
    this.batchId,
    this.sectionId,
    this.status,
    this.loginStatus,
  });

  final StudentManagementRepository repository;
  final StudentFilterOptionsData options;
  final int? academicSessionId;
  final int? programId;
  final int? semesterId;
  final int? batchId;
  final int? sectionId;
  final String? status;
  final String? loginStatus;

  @override
  State<_StudentFiltersDialog> createState() => _StudentFiltersDialogState();
}

class _StudentFiltersDialogState extends State<_StudentFiltersDialog> {
  late int? _academicSessionId = widget.academicSessionId;
  late int? _programId = widget.programId;
  late int? _semesterId = widget.semesterId;
  late int? _batchId = widget.batchId;
  late int? _sectionId = widget.sectionId;
  late String? _status = widget.status;
  late String? _loginStatus = widget.loginStatus;
  late StudentFilterOptionsData _options = widget.options;
  int _seq = 0;

  Future<void> _rescope() async {
    final seq = ++_seq;
    try {
      final options = await widget.repository.getFilterOptions(
        academicSessionId: _academicSessionId,
        programId: _programId,
        semesterId: _semesterId,
        batchId: _batchId,
        sectionId: _sectionId,
      );
      if (!mounted || seq != _seq) return;
      setState(() => _options = options);
    } on ApiException {
      // Keep the current options; the user can still apply what they picked.
    } catch (_) {
      // Same as above - best-effort re-scoping only.
    }
  }

  void _onSession(int? value) {
    setState(() {
      _academicSessionId = value;
      _programId = null;
      _semesterId = null;
      _batchId = null;
      _sectionId = null;
    });
    _rescope();
  }

  void _onProgram(int? value) {
    setState(() {
      _programId = value;
      _semesterId = null;
      _batchId = null;
      _sectionId = null;
    });
    _rescope();
  }

  void _onSemester(int? value) {
    setState(() {
      _semesterId = value;
      _batchId = null;
      _sectionId = null;
    });
    _rescope();
  }

  void _onBatch(int? value) {
    setState(() {
      _batchId = value;
      _sectionId = null;
    });
    _rescope();
  }

  void _onSection(int? value) {
    setState(() => _sectionId = value);
    _rescope();
  }

  void _clear() {
    setState(() {
      _academicSessionId = null;
      _programId = null;
      _semesterId = null;
      _batchId = null;
      _sectionId = null;
      _status = null;
      _loginStatus = null;
    });
    _rescope();
  }

  void _apply() {
    Navigator.of(context).pop(_StudentFilterSelection(
      academicSessionId: _academicSessionId,
      programId: _programId,
      semesterId: _semesterId,
      batchId: _batchId,
      sectionId: _sectionId,
      status: _status,
      loginStatus: _loginStatus,
    ));
  }

  Widget _intField({
    required Key key,
    required String label,
    required int? value,
    required List<StudentFilterOption> options,
    required ValueChanged<int?> onChanged,
  }) {
    return AppFormDropdown<int?>(
      key: key,
      label: label,
      value: value,
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...options.map((o) => DropdownMenuItem<int?>(
            value: o.id, child: Text(o.displayName))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filter Students',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('filter-dialog-clear'),
                tooltip: 'Clear filters',
                onPressed: _clear,
                icon: const Icon(Icons.filter_alt_off),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _intField(
            key: const Key('filter-academic-session'),
            label: 'Academic Session',
            value: _academicSessionId,
            options: _options.academicSessions,
            onChanged: _onSession,
          ),
          _intField(
            key: const Key('filter-program'),
            label: 'Program',
            value: _programId,
            options: _options.programs,
            onChanged: _onProgram,
          ),
          _intField(
            key: const Key('filter-semester'),
            label: 'Semester',
            value: _semesterId,
            options: _options.semesters,
            onChanged: _onSemester,
          ),
          _intField(
            key: const Key('filter-batch'),
            label: 'Batch',
            value: _batchId,
            options: _options.batches,
            onChanged: _onBatch,
          ),
          _intField(
            key: const Key('filter-section'),
            label: 'Section',
            value: _sectionId,
            options: _options.sections,
            onChanged: _onSection,
          ),
          AppFormDropdown<String?>(
            key: const Key('filter-status'),
            label: 'Status',
            value: _status,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All')),
              DropdownMenuItem<String?>(
                  value: 'ACTIVE', child: Text('ACTIVE')),
              DropdownMenuItem<String?>(
                  value: 'INACTIVE', child: Text('INACTIVE')),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
          AppFormDropdown<String?>(
            key: const Key('filter-login-status'),
            label: 'Login Status',
            value: _loginStatus,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All')),
              DropdownMenuItem<String?>(
                  value: 'ACTIVE', child: Text('LOGIN ACTIVE')),
              DropdownMenuItem<String?>(
                  value: 'NONE', child: Text('NO LOGIN')),
            ],
            onChanged: (v) => setState(() => _loginStatus = v),
          ),
          const SizedBox(height: 8),
          AppFormActions(
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _apply,
            submitting: false,
            submitKey: 'filter-dialog-apply',
            submitLabel: 'Apply Filters',
          ),
        ],
      ),
    );
  }
}

enum _StudentDetailAction { edit, toggle, createLogin, resetPassword, toggleLogin, downloadCredentials }

class _CreateLoginConfirmDialog extends StatelessWidget {
  const _CreateLoginConfirmDialog({required this.studentName});

  final String studentName;

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Login for $studentName',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text(
              'The system will generate a secure temporary password. '
              'The student must change it on their first sign-in.'),
          const SizedBox(height: 8),
          Text(
            'A valid email on the student profile is required to link the '
            'login account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          AppFormActions(
            onCancel: () => Navigator.of(context).pop(false),
            onSubmit: () => Navigator.of(context).pop(true),
            submitting: false,
            submitKey: 'confirm-create-login',
            submitLabel: 'Create Login',
          ),
        ],
      ),
    );
  }
}

class _TemporaryCredentialsDialog extends StatelessWidget {
  const _TemporaryCredentialsDialog({required this.student});

  final StudentManagement student;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) {
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
            Expanded(child: Text(value)),
          ],
        ),
      );
    }

    return AppDialogFrame(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Login Created',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Divider(height: 28),
          row('Student', student.name ?? '-'),
          row('Roll Number', student.rollNumber ?? '-'),
          row('Temporary Password', student.temporaryPassword ?? ''),
          const Divider(height: 28),
          Text(
            'Copy and share this temporary password with the student once - '
            'it will not be shown again. The student must change it after '
            'signing in with their roll number.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              key: const Key('temporary-credentials-done'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

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
  int? _academicSessionId;
  int? _semesterId;
  String? _status;

  bool _loadingReferences = true;
  bool _loadingSemesters = false;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<AcademicSession> _academicSessions = const [];
  List<Program> _programs = const [];
  List<Batch> _batches = const [];
  List<Section> _sections = const [];
  List<Semester> _semesters = const [];

  TextEditingController _controller(String? value) =>
      TextEditingController(text: value ?? '');

  bool get _isEdit => widget.initial != null;

  /// Batches belonging to the selected academic session whose legacy
  /// program-name snapshot matches the selected program.
  ///
  /// Note: `BatchDTO` exposes only the legacy `program` name string, not a
  /// relational program id, so client-side filtering relies on that snapshot.
  /// The backend remains authoritative via Batch -> AcademicSession -> Program.
  List<Batch> _batchesFor(int? sessionId, int? programId) {
    final sessionBatches = sessionId == null
        ? _batches.where((b) => b.academicSessionId == null).toList()
        : _batches.where((b) => b.academicSessionId == sessionId).toList();
    final programName = _programs
        .where((p) => p.id == programId)
        .map((p) => p.name)
        .firstOrNull;
    if (programName == null) return sessionBatches;
    return sessionBatches.where((b) => b.program == programName).toList();
  }

  List<Section> _sectionsForBatch(int? batchId) {
    if (batchId == null) return const [];
    return _sections.where((s) => s.batchId == batchId).toList();
  }

  /// Keeps the edit-mode pre-selection only when it belongs to the selected
  /// program; otherwise falls back to the first consistent batch.
  int? _resolveBatchId(int? preferred, int? sessionId, int? programId) {
    final matches = _batchesFor(sessionId, programId);
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
      final sessions = await widget.masterDataRepository.getAcademicSessions();
      final programs = await widget.masterDataRepository.getPrograms();
      final batches = await widget.masterDataRepository.getBatches();
      final sections = await widget.masterDataRepository.getSections();
      if (!mounted) return;
      setState(() {
        _academicSessions = sessions;
        _programs = programs;
        _batches = batches;
        _sections = sections;
        _academicSessionId =
            widget.initial?.academicSessionId ?? sessions.firstOrNull?.id;
        _programId = widget.initial?.programId ?? programs.firstOrNull?.id;
        _batchId =
            _resolveBatchId(widget.initial?.batchId, _academicSessionId, _programId);
        _sectionId = _resolveSectionId(widget.initial?.sectionId, _batchId);
        _loadingReferences = false;
      });
      await _loadSemesters(_academicSessionId);
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

  Future<void> _loadSemesters(int? sessionId) async {
    if (sessionId == null) {
      if (!mounted) return;
      setState(() {
        _semesters = const [];
        _semesterId = null;
        _loadingSemesters = false;
      });
      return;
    }
    setState(() => _loadingSemesters = true);
    List<Semester> semesters;
    try {
      semesters = await widget.masterDataRepository.getSemestersBySession(sessionId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _semesters = const [];
        _semesterId = null;
        _loadingSemesters = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      var keep = widget.initial?.semesterId;
      if (keep != null && !semesters.any((s) => s.id == keep)) {
        keep = null;
      }
      _semesters = semesters;
      _semesterId = keep;
      _loadingSemesters = false;
    });
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
      academicSessionId: _academicSessionId,
      batchId: _batchId,
      sectionId: _sectionId,
      semesterId: _semesterId,
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
            key: const Key('field-academic-session'),
            label: 'Academic Session',
            value: _academicSessionId,
            items: _academicSessions
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name ?? s.code ?? 'Unknown')))
                .toList(),
            onChanged: (v) {
              setState(() {
                _academicSessionId = v;
                _programId = null;
                _batchId = null;
                _sectionId = null;
                _semesterId = null;
              });
              _loadSemesters(v);
            },
            validator: (v) => v == null ? 'Academic Session is required' : null,
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
              _batchId = _batchesFor(_academicSessionId, v).firstOrNull?.id;
              _sectionId = _sectionsForBatch(_batchId).firstOrNull?.id;
            }),
            validator: (v) => v == null ? 'Program is required' : null,
          ),
          if (_loadingSemesters)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_semesters.isNotEmpty)
            AppFormDropdown<int>(
              key: const Key('field-semester'),
              label: 'Semester',
              value: _semesterId,
              items: _semesters
                  .where((s) => s.id != null)
                  .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name ?? ''} '
                          '${s.code ?? ''}'.trim())))
                  .toList(),
              onChanged: (v) => setState(() => _semesterId = v),
            ),
          AppFormDropdown<int>(
            key: const Key('field-batch'),
            label: 'Batch',
            value: _batchId,
            items: _batchesFor(_academicSessionId, _programId)
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
  StudentImportResult? _previewResult;
  bool _previewing = false;

  Future<void> _chooseFile() async {
    setState(() {
      _error = null;
      _result = null;
      _previewResult = null;
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

  Future<void> _preview() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _previewing = true;
      _error = null;
      _previewResult = null;
    });
    try {
      final result = await widget.repository.previewImport(
        filename: file.name,
        bytes: file.bytes,
      );
      if (!mounted) return;
      setState(() {
        _previewing = false;
        _previewResult = result;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _previewing = false;
        _error = _importErrorFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewing = false;
        _error = 'Could not preview the file. Please try again.';
      });
    }
  }

  Future<void> _import() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
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
        _previewResult = null;
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

  bool get _allRowsValid => _previewResult != null && _previewResult!.isSuccess;

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
          'Name, Roll Number, Academic Session, Program (required). '
          'Semester, Batch, Section (optional). '
          'Enrollment Number is derived from Roll Number if absent. '
          'Import is all-or-nothing: if any row is invalid, no students are added.',
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
          const SizedBox(height: 8),
          if (_previewResult == null && !_previewing) ...[
            ElevatedButton.icon(
              key: const Key('preview-import'),
              onPressed: _previewing ? null : _preview,
              icon: const Icon(Icons.visibility),
              label: const Text('Preview & Validate'),
            ),
          ],
          if (_previewing) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          ],
          if (_previewResult != null && !_previewResult!.isSuccess) ...[
            const SizedBox(height: 8),
            Text(
              '${_previewResult!.totalRows} rows detected. '
              '${_previewResult!.rejectedRows} invalid.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 4),
            ..._previewResult!.errors.map((e) => _buildErrorRow(e, 0)),
          ],
          if (_previewResult != null && _previewResult!.isSuccess) ...[
            const SizedBox(height: 8),
            Text(
              'All ${_previewResult!.totalRows} rows are valid.',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
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
              onPressed: _submitting || !hasFile || !_allRowsValid ? null : _import,
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
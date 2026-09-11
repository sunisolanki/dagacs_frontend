import 'package:flutter/material.dart';

import '../../core/theme/dagacs_theme.dart';
import '../../models/department.dart';
import '../../models/teacher_management.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../repositories/teacher_management_repository.dart';
import '../../widgets/dagacs_widgets.dart';
import 'teacher_form.dart';

/// ADMIN-only Manage Teachers screen (M9.5.1 + M9.5.3).
///
/// Full teacher-master management plus the account lifecycle the admin owns:
/// view/create/edit profile, activate/deactivate the profile, provision the
/// login account, reset its password, activate/deactivate the login, and
/// designate/demote the HOD of a department (reusing the frozen
/// `PATCH /api/admin/teachers/{id}/hod`).
///
/// Profile status and login status stay independent (D4): deactivating the
/// profile never touches the login and vice-versa. Both are shown as separate
/// badges. Backend authorization is authoritative - the whole surface is
/// ADMIN-only on the server; an Admin teacher never sees a password in any
/// response (write-only, D3).
class TeacherListScreen extends StatefulWidget {
  const TeacherListScreen({
    super.key,
    required this.repository,
    required this.masterDataRepository,
  });

  final TeacherManagementRepository repository;
  final MasterDataRepository masterDataRepository;

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  List<TeacherManagement> _teachers = const [];
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
      final teachers = await widget.repository.getTeachers();
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
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
        _error = 'Something went wrong while loading teachers.';
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
        return 'Your role does not have access to manage teachers. '
            'This area is ADMIN-only on the backend.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
  }

  List<TeacherManagement> get _visibleTeachers {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _teachers;
    return _teachers.where((t) {
      final name = t.fullName?.toLowerCase() ?? '';
      final email = t.email?.toLowerCase() ?? '';
      final designation = t.designation?.toLowerCase() ?? '';
      final department = t.departmentName?.toLowerCase() ?? '';
      return name.contains(query) ||
          email.contains(query) ||
          designation.contains(query) ||
          department.contains(query);
    }).toList();
  }

  Future<void> _openCreate() async {
    final created = await showTeacherFormDialog(
      context: context,
      repository: widget.repository,
      masterDataRepository: widget.masterDataRepository,
    );
    if (created != null) _load();
  }

  Future<void> _openEdit(TeacherManagement teacher) async {
    final updated = await showTeacherFormDialog(
      context: context,
      repository: widget.repository,
      masterDataRepository: widget.masterDataRepository,
      initial: teacher,
    );
    if (updated != null) _load();
  }

  Future<void> _openDetail(TeacherManagement teacher) async {
    final action = await showDialog<_TeacherDetailAction>(
      context: context,
      builder: (dialogContext) => _TeacherDetailDialog(
        teacher: teacher,
        onEdit: () => Navigator.of(dialogContext).pop(_TeacherDetailAction.edit),
        onToggleProfile: () =>
            Navigator.of(dialogContext).pop(_TeacherDetailAction.toggleProfile),
        onCreateLogin: () =>
            Navigator.of(dialogContext).pop(_TeacherDetailAction.createLogin),
        onResetPassword: () =>
            Navigator.of(dialogContext).pop(_TeacherDetailAction.resetPassword),
        onToggleLogin: () =>
            Navigator.of(dialogContext).pop(_TeacherDetailAction.toggleLogin),
        onDesignateHod: () =>
            Navigator.of(dialogContext).pop(_TeacherDetailAction.designateHod),
        onDemoteHod: () =>
            Navigator.of(dialogContext).pop(_TeacherDetailAction.demoteHod),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _TeacherDetailAction.edit) {
      await _openEdit(teacher);
    } else if (action == _TeacherDetailAction.toggleProfile) {
      await _setTeacherStatus(
          teacher, teacher.isActive ? 'INACTIVE' : 'ACTIVE');
    } else if (action == _TeacherDetailAction.createLogin) {
      await _createLogin(teacher);
    } else if (action == _TeacherDetailAction.resetPassword) {
      await _resetPassword(teacher);
    } else if (action == _TeacherDetailAction.toggleLogin) {
      await _setLoginStatus(
          teacher, teacher.loginIsActive ? 'INACTIVE' : 'ACTIVE');
    } else if (action == _TeacherDetailAction.designateHod) {
      await _designateHod(teacher);
    } else if (action == _TeacherDetailAction.demoteHod) {
      await _demoteHod(teacher);
    }
  }

  Future<void> _showError(String message) {
    if (!mounted) return Future.value();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    return Future.value();
  }

  Future<void> _setTeacherStatus(
      TeacherManagement teacher, String status) async {
    try {
      await widget.repository.setTeacherStatus(teacher.id!, status);
      if (!mounted) return;
      await _load();
    } on ApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not change profile status. Please try again.')));
    }
  }

  Future<void> _createLogin(TeacherManagement teacher) async {
    final password = await _promptPassword(
      context: context,
      title: 'Create Login for ${teacher.fullName ?? 'Teacher'}',
      submitLabel: 'Create Login',
    );
    if (password == null || !mounted) return;
    try {
      await widget.repository.provisionLogin(
          teacher.id!, TeacherLoginPasswordRequest(password));
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      await _showError(
          'Could not create the login. ${_reasonFor(e)} Please try again.');
    }
  }

  Future<void> _resetPassword(TeacherManagement teacher) async {
    final password = await _promptPassword(
      context: context,
      title: 'Reset Password for ${teacher.fullName ?? 'Teacher'}',
      submitLabel: 'Reset Password',
    );
    if (password == null || !mounted) return;
    try {
      await widget.repository
          .setLoginPassword(teacher.id!, TeacherLoginPasswordRequest(password));
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

  Future<void> _setLoginStatus(
      TeacherManagement teacher, String status) async {
    try {
      await widget.repository.setLoginStatus(teacher.id!, status);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      await _showError(
          'Could not change the login status. ${_reasonFor(e)} Please try again.');
    }
  }

  Future<void> _designateHod(TeacherManagement teacher) async {
    final departmentId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _HodDesignationDialog(
        repository: widget.masterDataRepository,
        teacherName: teacher.fullName,
      ),
    );
    if (departmentId == null || !mounted) return;
    try {
      final hod = await widget.repository.designateHod(
          teacher.id!,
          TeacherHodDesignationRequest(
              designated: true, departmentId: departmentId));
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${hod.teacherName ?? 'Teacher'} is now the HOD of '
              '${hod.departmentName ?? 'the department'}.')));
    } on ApiException catch (e) {
      await _showError(
          'Could not designate the HOD. ${_reasonFor(e)} Please try again.');
    }
  }

  Future<void> _demoteHod(TeacherManagement teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: 'Remove HOD',
        message:
            'Remove ${teacher.fullName ?? 'this teacher'} as HOD of '
            '${teacher.departmentName ?? 'the department'}? The teacher keeps '
            'their profile, department and login.',
        confirmLabel: 'Remove HOD',
        confirmKey: const Key('confirm-demote-hod'),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.designateHod(
          teacher.id!,
          const TeacherHodDesignationRequest(designated: false));
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('HOD designation removed.')));
    } on ApiException catch (e) {
      await _showError(
          'Could not remove the HOD. ${_reasonFor(e)} Please try again.');
    }
  }

  String _reasonFor(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return 'The password must be at least 8 characters.';
      case 404:
        return 'This teacher no longer exists.';
      case 409:
        return 'A teacher or student with that email already has a login.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Teachers')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-teacher'),
        tooltip: 'Add teacher',
        onPressed: _openCreate,
        child: const Icon(Icons.person_add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading teachers...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_teachers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.person_off_outlined,
        message: 'No teachers found. Use + to add one.',
      );
    }
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildTeacherList()),
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
          key: const Key('teacher-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search by name, email, designation, or department',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    key: const Key('teacher-search-clear'),
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

  Widget _buildTeacherList() {
    final visible = _visibleTeachers;
    if (visible.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off,
        message: 'No teachers match',
      );
    }
    return ListView.builder(
      key: const Key('teacher-list'),
      padding: EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        0,
        DagacsSpace.lg,
        96,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final teacher = visible[index];
        final hasLogin = teacher.hasLogin;
        return Padding(
          padding: const EdgeInsets.only(bottom: DagacsSpace.sm + 2),
          child: AppCard(
            key: Key('teacher-tile-${teacher.id}'),
            onTap: () => _openDetail(teacher),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            child: Row(
              children: [
                AppAvatar(name: teacher.fullName, size: 44),
                const SizedBox(width: DagacsSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.fullName ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (teacher.designation != null &&
                              teacher.designation!.isNotEmpty)
                            teacher.designation,
                          if (teacher.departmentName != null &&
                              teacher.departmentName!.isNotEmpty)
                            teacher.departmentName,
                          teacher.email,
                        ].whereType<String>().join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DagacsSpace.sm),
                if (teacher.isHod == true) ...[
                  const _HodChip(),
                  const SizedBox(width: 6),
                ],
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppStatusBadge(
                      label: teacher.status ?? '-',
                      active: teacher.isActive,
                    ),
                    const SizedBox(height: 4),
                    AppStatusBadge(
                      label: hasLogin
                          ? (teacher.loginIsActive ? 'LOGIN ACTIVE' : 'LOGIN INACTIVE')
                          : 'NO LOGIN',
                      active: hasLogin && teacher.loginIsActive,
                    ),
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

enum _TeacherDetailAction {
  edit,
  toggleProfile,
  createLogin,
  resetPassword,
  toggleLogin,
  designateHod,
  demoteHod,
}

class _HodChip extends StatelessWidget {
  const _HodChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DagacsColors.warningBg,
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
      ),
      child: const Text(
        'HOD',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: DagacsColors.warning,
        ),
      ),
    );
  }
}

class _TeacherDetailDialog extends StatelessWidget {
  const _TeacherDetailDialog({
    required this.teacher,
    required this.onEdit,
    required this.onToggleProfile,
    required this.onCreateLogin,
    required this.onResetPassword,
    required this.onToggleLogin,
    required this.onDesignateHod,
    required this.onDemoteHod,
  });

  final TeacherManagement teacher;
  final VoidCallback onEdit;
  final VoidCallback onToggleProfile;
  final VoidCallback onCreateLogin;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleLogin;
  final VoidCallback onDesignateHod;
  final VoidCallback onDemoteHod;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String? value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
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

    final hasLogin = teacher.hasLogin;
    return AppDialogFrame(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: teacher.fullName, size: 44),
              const SizedBox(width: DagacsSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.fullName ?? 'Teacher',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (teacher.isHod == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: _HodChip(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          row('Email', teacher.email),
          row('Designation', teacher.designation),
          row('Department', teacher.departmentName),
          row('Phone', teacher.phone),
          row('Profile Status', teacher.status),
          const Divider(height: 28),
          Text('Login Account',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          row('Linked', hasLogin ? 'Yes' : 'No'),
          if (hasLogin) row('Login Status', teacher.loginStatus),
          const SizedBox(height: DagacsSpace.sm),
          Wrap(
            spacing: DagacsSpace.sm,
            runSpacing: DagacsSpace.sm,
            children: [
              OutlinedButton(
                key: const Key('detail-toggle-profile'),
                onPressed: onToggleProfile,
                child:
                    Text(teacher.isActive ? 'Deactivate Profile' : 'Activate Profile'),
              ),
              if (!hasLogin)
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
                  child: Text(teacher.loginIsActive
                      ? 'Deactivate Login'
                      : 'Activate Login'),
                ),
              ],
              if (teacher.isHod == true)
                OutlinedButton(
                  key: const Key('detail-demote-hod'),
                  onPressed: onDemoteHod,
                  child: const Text('Remove HOD'),
                )
              else
                OutlinedButton(
                  key: const Key('detail-designate-hod'),
                  onPressed: onDesignateHod,
                  child: const Text('Designate HOD'),
                ),
              ElevatedButton(
                key: const Key('detail-edit-teacher'),
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
    builder: (dialogContext) => _PasswordDialog(
      title: title,
      submitLabel: submitLabel,
    ),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.title, required this.submitLabel});

  final String title;
  final String submitLabel;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
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
            Text(widget.title,
                style: Theme.of(context).textTheme.titleLarge),
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

/// Department picker for designating a HOD (loads live departments, never
/// hardcoded).
class _HodDesignationDialog extends StatefulWidget {
  const _HodDesignationDialog({
    required this.repository,
    required this.teacherName,
  });

  final MasterDataRepository repository;
  final String? teacherName;

  @override
  State<_HodDesignationDialog> createState() => _HodDesignationDialogState();
}

class _HodDesignationDialogState extends State<_HodDesignationDialog> {
  List<Department> _departments = const [];
  bool _loading = true;
  String? _error;
  int? _selected;

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
      final departments = await widget.repository.getDepartments();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _selected = departments.firstOrNull?.id;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load departments.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load departments.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      width: 440,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Designate HOD',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${widget.teacherName ?? 'This teacher'} will lead the chosen '
            'department. Any existing HOD of that department is replaced.'),
        const SizedBox(height: 16),
        AppFormDropdown<int>(
          key: const Key('field-hod-department'),
          label: 'Department',
          value: _selected,
          items: _departments
              .where((d) => d.id != null)
              .map((d) => DropdownMenuItem(
                  value: d.id, child: Text(d.name ?? 'Unknown')))
              .toList(),
          onChanged: (v) => setState(() => _selected = v),
          validator: (v) => v == null ? 'Choose a department' : null,
        ),
        const SizedBox(height: 8),
        AppFormActions(
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            if (_selected == null) return;
            Navigator.of(context).pop(_selected);
          },
          submitting: false,
          submitKey: 'submit-designate-hod',
          submitLabel: 'Designate',
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../network/api_exception.dart';
import '../repositories/student_profile_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';
import '../core/session/session_controller.dart';
import '../widgets/app_module_scaffold.dart';

/// Student profile of the authenticated student (M5.1).
///
/// The backend resolves the identity from the JWT — no studentId is accepted
/// from the client. Internal account email is not exposed to the student UI.
/// The student may edit Father's Name, Mother's Name, and Gender.
/// All other fields remain read-only.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen(
      {super.key, required this.profileRepository, this.session});

  final StudentProfileRepository profileRepository;

  /// Phase 5.4: see StudentAttendanceScreen.session.
  final SessionController? session;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  StudentProfile? _profile;
  bool _editing = false;

    final _fatherNameController = TextEditingController();
    final _motherNameController = TextEditingController();
    final _genderController = TextEditingController();
    final _personalEmailController = TextEditingController();

  @override
  void dispose() {
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _genderController.dispose();
    _personalEmailController.dispose();
    super.dispose();
  }

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

    StudentProfile? profile;
    String? error;
    try {
      profile = await widget.profileRepository.getMyProfile();
    } on ApiException catch (e) {
      error = _messageFor(e);
    } catch (_) {
      error = 'Something went wrong while loading your profile.';
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_profile == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{};
      if (_fatherNameController.text.isNotEmpty) {
        data['fatherName'] = _fatherNameController.text;
      }
      if (_motherNameController.text.isNotEmpty) {
        data['motherName'] = _motherNameController.text;
      }
      if (_genderController.text.isNotEmpty) {
        data['gender'] = _genderController.text;
      }
      if (_personalEmailController.text.isNotEmpty) {
        data['personalEmail'] = _personalEmailController.text;
      }
      final updated = await widget.profileRepository.updateMyProfile(data);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _editing = false;
        _saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong while saving your profile.';
      });
    }
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  void _startEditing() {
    if (_profile == null) return;
    _fatherNameController.text = _profile!.fatherName ?? '';
    _motherNameController.text = _profile!.motherName ?? '';
    _genderController.text = _profile!.gender ?? '';
    _personalEmailController.text = _profile!.personalEmail ?? '';
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = _editing
        ? [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: _saving ? null : _save,
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel',
              onPressed: _saving ? null : _cancel,
            ),
          ]
        : [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit profile',
              onPressed: _startEditing,
            ),
          ];

    // Phase 5.4: see StudentAttendanceScreen.session. With a session the screen
    // joins the shared navigation frame; without one it is unchanged.
    final session = widget.session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile'), actions: actions),
        body: _buildBody(),
      );
    }
    return AppModuleScaffold(
      session: session,
      title: 'My Profile',
      actions: actions,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading your profile...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }

    final profile = _profile;
    if (profile == null) {
      return const AppEmptyState(
        icon: Icons.person_off_outlined,
        message: 'Your profile is not available yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DagacsSpace.lg),
        children: [
          _buildHeader(profile),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _buildRow(Icons.badge_outlined, 'Roll Number', profile.rollNumber),
                _buildRow(Icons.fact_check_outlined, 'Enrollment Number', profile.enrollmentNumber),
                _buildEditableOrReadOnly(Icons.person_outline, 'Gender', profile.gender, _genderController, _editing),
                _buildEditableOrReadOnly(Icons.email_outlined, 'Personal Email', profile.personalEmail, _personalEmailController, _editing),
                _buildEditableOrReadOnly(Icons.man_outlined, "Father's Name", profile.fatherName, _fatherNameController, _editing),
                _buildEditableOrReadOnly(Icons.woman_outlined, "Mother's Name", profile.motherName, _motherNameController, _editing),
                _buildRow(Icons.cake_outlined, 'Age', profile.age?.toString()),
                _buildRow(Icons.event_outlined, 'Admission Date', profile.admissionDate),
                _buildRow(Icons.health_and_safety_outlined, 'Status', profile.status),
                if (_editing && _saving) const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _buildRow(Icons.account_tree_outlined, 'Program', profile.programName),
                _buildRow(Icons.group_outlined, 'Batch', profile.batchName),
                _buildRow(Icons.chair_outlined, 'Section', profile.sectionName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableOrReadOnly(
    IconData icon,
    String label,
    String? value,
    TextEditingController controller,
    bool editing,
  ) {
    if (!editing) {
      return _buildRow(icon, label, value);
    }
    // Phase 5.4: this used to be a `ListTile.trailing` holding a field of a
    // fixed 200 px. With the leading icon, the label and the tile's own padding
    // that left roughly 120 px on a 320 dp phone, which is not enough to type in
    // and which overflowed outright on a narrow device. The field is now the
    // tile's own content - stacked under the label - so it gets the full width
    // at every size and needs no breakpoint at all.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg, DagacsSpace.sm, DagacsSpace.lg, DagacsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DagacsColors.brandPrimary, size: 22),
          const SizedBox(width: DagacsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: DagacsSpace.xs),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: value ?? '',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(StudentProfile profile) {
    final name = profile.name ?? '-';
    final photoUrl = profile.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: DagacsColors.brandPrimary,
          foregroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
          child: hasPhoto
              ? null
              : Text(
                  initials.isEmpty ? '?' : initials,
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (profile.rollNumber != null)
          Text(
            profile.rollNumber!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DagacsColors.textSecondary,
                ),
          ),
      ],
    );
  }

  Widget _buildRow(IconData icon, String label, String? value) {
    return ListTile(
      leading: Icon(icon, color: DagacsColors.brandPrimary),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Text(
        value ?? '-',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

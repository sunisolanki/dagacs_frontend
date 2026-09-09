import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../network/api_exception.dart';
import '../repositories/student_profile_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';

/// Read-only academic profile of the authenticated student (M5.1).
///
/// The backend resolves the identity from the JWT — no studentId is accepted
/// from the client. All values are backend-authoritative; Flutter only renders
/// the returned profile.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key, required this.profileRepository});

  final StudentProfileRepository profileRepository;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _loading = true;
  String? _error;
  StudentProfile? _profile;

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

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
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
                _buildRow(
                    Icons.fact_check_outlined, 'Enrollment Number', profile.enrollmentNumber),
                _buildRow(Icons.mail_outline, 'Email', profile.email),
                _buildRow(Icons.person_outline, 'Gender', profile.gender),
                _buildRow(Icons.man_outlined, "Father's Name", profile.fatherName),
                _buildRow(Icons.woman_outlined, "Mother's Name", profile.motherName),
                _buildRow(Icons.cake_outlined, 'Age', profile.age?.toString()),
                _buildRow(
                    Icons.event_outlined, 'Admission Date', profile.admissionDate),
                _buildRow(Icons.health_and_safety_outlined, 'Status', profile.status),
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
                color: DagacsColors.textSecondary),
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

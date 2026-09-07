import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../network/api_exception.dart';
import '../repositories/student_profile_repository.dart';

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
    switch (e.statusCode) {
      case 401:
        return 'Session expired. Please sign in again.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
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

    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('Profile unavailable'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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
          backgroundColor: const Color(0xFF1A73E8),
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
                color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildRow(IconData icon, String label, String? value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1A73E8)),
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
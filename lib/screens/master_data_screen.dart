import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../network/api_exception.dart';
import '../repositories/master_data_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// ADMIN-only Master Data hub.
///
/// Presents the seven academic master-data entities (Departments, Programs,
/// Academic Sessions, Semesters, Batches, Sections, Subjects) with live record
/// counts and entry to each entity's CRUD list. Non-ADMIN roles see an
/// informational screen - backend RBAC (`/api/admin/**` requires ADMIN) stays
/// authoritative.
class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen(
      {super.key, required this.repository, required this.session});

  final MasterDataRepository repository;
  final SessionController session;

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  bool _loading = false;
  String? _error;
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    if (widget.session.role == 'ADMIN') {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final departments = await widget.repository.getDepartments();
      final programs = await widget.repository.getPrograms();
      final sessions = await widget.repository.getAcademicSessions();
      final semesters = await widget.repository.getSemesters();
      final batches = await widget.repository.getBatches();
      final sections = await widget.repository.getSections();
      final subjects = await widget.repository.getSubjects();
      if (!mounted) return;
      setState(() {
        _counts = {
          'departments': departments.length,
          'programs': programs.length,
          'academic-sessions': sessions.length,
          'semesters': semesters.length,
          'batches': batches.length,
          'sections': sections.length,
          'subjects': subjects.length,
        };
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userMessageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading master data.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Data')),
      body: widget.session.role == 'ADMIN' ? _buildAdmin() : _buildNotAdmin(),
    );
  }

  Widget _buildNotAdmin() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(DagacsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(
              icon: Icons.lock_outline,
              color: DagacsColors.textSecondary,
              backgroundColor: DagacsColors.surfaceAlt,
              size: 64,
            ),
            SizedBox(height: DagacsSpace.lg),
            Text(
              'Master data management is ADMIN-only.',
              textAlign: TextAlign.center,
              style: DagacsTextStyles.sectionTitle,
            ),
            SizedBox(height: DagacsSpace.sm),
            Text(
              'Your role does not have access to this area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: DagacsColors.textSecondary,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdmin() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading master data...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: DagacsSpace.lg),
        children: [
          AppConstrainedMax(
            maxWidth: 1120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageHeader(
                  icon: Icons.storage_outlined,
                  title: 'Master Data',
                  subtitle:
                      'Manage the academic master entities of the institution',
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
                  child: AppResponsiveGrid(
                    children: [
                      _card(
                        key: 'master-data-departments',
                        route: '/master-data/departments',
                        icon: Icons.account_balance_outlined,
                        title: 'Departments',
                        count: _counts['departments'] ?? 0,
                      ),
                      _card(
                        key: 'master-data-programs',
                        route: '/master-data/programs',
                        icon: Icons.school_outlined,
                        title: 'Programs',
                        count: _counts['programs'] ?? 0,
                      ),
                      _card(
                        key: 'master-data-academic-sessions',
                        route: '/master-data/academic-sessions',
                        icon: Icons.calendar_month_outlined,
                        title: 'Academic Sessions',
                        count: _counts['academic-sessions'] ?? 0,
                      ),
                      _card(
                        key: 'master-data-semesters',
                        route: '/master-data/semesters',
                        icon: Icons.layers_outlined,
                        title: 'Semesters',
                        count: _counts['semesters'] ?? 0,
                      ),
                      _card(
                        key: 'master-data-batches',
                        route: '/master-data/batches',
                        icon: Icons.groups_outlined,
                        title: 'Batches',
                        count: _counts['batches'] ?? 0,
                      ),
                      _card(
                        key: 'master-data-sections',
                        route: '/master-data/sections',
                        icon: Icons.view_agenda_outlined,
                        title: 'Sections',
                        count: _counts['sections'] ?? 0,
                      ),
                      _card(
                        key: 'master-data-subjects',
                        route: '/master-data/subjects',
                        icon: Icons.book_outlined,
                        title: 'Subjects',
                        count: _counts['subjects'] ?? 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String key,
    required String route,
    required IconData icon,
    required String title,
    required int count,
  }) {
    return AppFeatureTile(
      key: Key(key),
      icon: icon,
      title: title,
      subtitle: '$count record${count == 1 ? '' : 's'}',
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
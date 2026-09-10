import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../network/api_exception.dart';
import '../repositories/master_data_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// ADMIN-only Master Data hub.
///
/// Presents the seven academic master-data entities (Departments, Programs,
/// Academic Sessions, Semesters, Batches, Sections, Subjects) grouped into
/// four professional categories, each with a short description, a live record
/// count (from the repository, not faked) and entry to the entity's CRUD list.
/// Non-ADMIN roles see an informational screen - backend RBAC
/// (`/api/admin/**` requires ADMIN) stays authoritative.
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
                  subtitle:
                      'Manage the academic structure used across DAGACS.',
                ),
                _section(
                  label: 'Academic Structure',
                  icon: Icons.account_tree_outlined,
                  children: [
                    _card(
                      key: 'master-data-departments',
                      route: AppRoutes.masterDataDepartments,
                      icon: Icons.account_balance_outlined,
                      title: 'Departments',
                      description: 'Institutional academic departments',
                      count: _counts['departments'] ?? 0,
                    ),
                    _card(
                      key: 'master-data-programs',
                      route: AppRoutes.masterDataPrograms,
                      icon: Icons.school_outlined,
                      title: 'Programs',
                      description: 'Degree programs by department',
                      count: _counts['programs'] ?? 0,
                    ),
                  ],
                ),
                _section(
                  label: 'Academic Calendar',
                  icon: Icons.calendar_month_outlined,
                  children: [
                    _card(
                      key: 'master-data-academic-sessions',
                      route: AppRoutes.masterDataAcademicSessions,
                      icon: Icons.calendar_month_outlined,
                      title: 'Academic Sessions',
                      description: 'Sessions grouped by program',
                      count: _counts['academic-sessions'] ?? 0,
                    ),
                    _card(
                      key: 'master-data-semesters',
                      route: AppRoutes.masterDataSemesters,
                      icon: Icons.layers_outlined,
                      title: 'Semesters',
                      description: 'Study periods within a session',
                      count: _counts['semesters'] ?? 0,
                    ),
                  ],
                ),
                _section(
                  label: 'Student Structure',
                  icon: Icons.groups_outlined,
                  children: [
                    _card(
                      key: 'master-data-batches',
                      route: AppRoutes.masterDataBatches,
                      icon: Icons.groups_outlined,
                      title: 'Batches',
                      description: 'Student cohorts per academic session',
                      count: _counts['batches'] ?? 0,
                    ),
                    _card(
                      key: 'master-data-sections',
                      route: AppRoutes.masterDataSections,
                      icon: Icons.view_agenda_outlined,
                      title: 'Sections',
                      description: 'Groups within a batch',
                      count: _counts['sections'] ?? 0,
                    ),
                  ],
                ),
                _section(
                  label: 'Academic Catalog',
                  icon: Icons.library_books_outlined,
                  children: [
                    _card(
                      key: 'master-data-subjects',
                      route: AppRoutes.masterDataSubjects,
                      icon: Icons.book_outlined,
                      title: 'Subjects',
                      description: 'Catalogue with credit hours and status',
                      count: _counts['subjects'] ?? 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String label,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg, DagacsSpace.lg, DagacsSpace.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: DagacsColors.textSecondary),
              const SizedBox(width: DagacsSpace.xs),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: DagacsColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DagacsSpace.sm),
          AppResponsiveGrid(children: children),
        ],
      ),
    );
  }

  Widget _card({
    required String key,
    required String route,
    required IconData icon,
    required String title,
    required String description,
    required int count,
  }) {
    return AppFeatureTile(
      key: Key(key),
      icon: icon,
      title: title,
      subtitle: description,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count record${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DagacsColors.textSecondary,
            ),
          ),
          const SizedBox(width: DagacsSpace.xs),
          const Icon(Icons.chevron_right,
              size: 20, color: DagacsColors.textSecondary),
        ],
      ),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
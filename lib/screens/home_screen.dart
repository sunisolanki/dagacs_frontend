import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../repositories/master_data_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// Authenticated home. Role-aware welcome plus navigation into each role's
/// modules (unchanged routes, tiles and role gating).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.masterDataRepository,
  });

  final SessionController session;
  final MasterDataRepository masterDataRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 24, color: DagacsColors.brandPrimary),
            const SizedBox(width: DagacsSpace.sm),
            Text('DAGACS',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DagacsSpace.sm),
            child: AppAvatar(name: session.fullName, size: 36),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: DagacsSpace.lg),
        children: [
          AppConstrainedMax(
            maxWidth: 1120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DagacsSpace.lg),
                  child: _buildWelcome(context),
                ),
                const SizedBox(height: DagacsSpace.lg),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
                  child: AppResponsiveGrid(
                    children: _buildTiles(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    final role = session.role;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DagacsSpace.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DagacsColors.brandPrimary, DagacsColors.brandDark],
        ),
        borderRadius: BorderRadius.circular(DagacsRadius.lg),
        boxShadow: DagacsColors.cardShadow,
      ),
      child: Row(
        children: [
          AppAvatar(
            name: session.fullName ?? role,
            size: 56,
            backgroundColor: Colors.white,
            foregroundColor: DagacsColors.brandDark,
          ),
          const SizedBox(width: DagacsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${session.fullName ?? role}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                if (session.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.email!,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: DagacsSpace.sm),
                Wrap(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(DagacsRadius.pill),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
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

  List<Widget> _buildTiles(BuildContext context) {
    final role = session.role;
    final tiles = <Widget>[];

    if (role == 'TEACHER') {
      tiles.add(
        AppFeatureTile(
          icon: Icons.event_available,
          title: 'Attendance',
          subtitle: 'Create sessions and mark student attendance',
          onTap: () => Navigator.pushNamed(context, '/teacher/attendance'),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('teacher-reports-tile'),
          icon: Icons.assignment,
          title: 'Reports',
          subtitle: 'Subject-wise attendance report and export',
          onTap: () => Navigator.pushNamed(context, '/teacher/reports'),
        ),
      );
    }
    if (role == 'STUDENT') {
      tiles.add(
        AppFeatureTile(
          icon: Icons.how_to_reg,
          title: 'My Attendance',
          subtitle: 'View your attendance records',
          onTap: () => Navigator.pushNamed(context, '/student/attendance'),
        ),
      );
      tiles.add(
        AppFeatureTile(
          icon: Icons.person_outline,
          title: 'My Profile',
          subtitle: 'View your academic profile details',
          onTap: () => Navigator.pushNamed(context, '/student/profile'),
        ),
      );
    }
    if (role == 'ADMIN') {
      tiles.add(
        AppFeatureTile(
          key: const Key('admin-master-data-tile'),
          icon: Icons.storage,
          title: 'Master Data',
          subtitle:
              'Departments, Programs, Sessions, Semesters, Batches, Sections, Subjects',
          onTap: () => Navigator.pushNamed(context, '/master-data'),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('admin-students-tile'),
          icon: Icons.group,
          title: 'Manage Students',
          subtitle: 'Admin student master - create, edit, activate/deactivate',
          onTap: () => Navigator.pushNamed(context, '/admin/students'),
        ),
      );
    }
    if (role == 'HOD') {
      tiles.add(
        AppFeatureTile(
          icon: Icons.dashboard_customize,
          title: 'HOD Dashboard',
          subtitle:
              'Department analytics: attendance, low attendance, rollups',
          onTap: () => Navigator.pushNamed(context, '/hod/dashboard'),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('hod-reports-tile'),
          icon: Icons.assessment_outlined,
          title: 'Reports',
          subtitle:
              'Daily lecture, coverage, rollups, low attendance and exports',
          onTap: () => Navigator.pushNamed(context, '/hod/reports'),
        ),
      );
    }
    return tiles;
  }

  Future<void> _logout(BuildContext context) async {
    await session.clearSession();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}
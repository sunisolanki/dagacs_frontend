import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../repositories/master_data_repository.dart';
import '../models/attendance_percentage.dart';
import '../models/subject_attendance.dart';
import '../repositories/attendance_repository.dart';
import '../widgets/app_shell.dart';
import '../widgets/dagacs_widgets.dart';
import '../widgets/attendance_summary_cards.dart';

/// Authenticated home. Role-aware welcome plus navigation into each role's
/// modules (unchanged routes, tiles and role gating).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.masterDataRepository,
    this.attendanceRepository,
  });

  final SessionController session;
  final MasterDataRepository masterDataRepository;
  final AttendanceRepository? attendanceRepository;

  @override
  Widget build(BuildContext context) {
    if (session.role == 'STUDENT' && session.mustChangePassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.studentChangePassword);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AppShell(
      session: session,
      // Built inside the shell so the tiles can read the shell's own
      // responsive state instead of re-deriving the breakpoint.
      body: Builder(
        builder: (context) {
          final sideNavVisible = AppShellScope.sideNavVisibleOf(context);
          return ListView(
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
                    if (session.role == 'STUDENT' && attendanceRepository != null)
                      _buildAttendanceSummary(context),
                    const SizedBox(height: DagacsSpace.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DagacsSpace.lg),
                      child: _buildSectionHeader(context),
                    ),
                    const SizedBox(height: DagacsSpace.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DagacsSpace.lg),
                      child: AppResponsiveGrid(
                        children: _buildTiles(context, sideNavVisible),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

Widget _buildAttendanceSummary(BuildContext context) {
     return FutureBuilder<AttendancePercentage>(
       future: attendanceRepository!.getOverallAttendanceCalculation(),
       builder: (context, overallSnapshot) {
         if (overallSnapshot.connectionState == ConnectionState.waiting) {
           return const Padding(
             padding: EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
             child: AppLoadingState(message: 'Loading attendance summary...'),
           );
         }
         final subjectsFuture = attendanceRepository!.getSubjectAttendanceSummaries();
         return FutureBuilder<List<SubjectAttendance>>(
           future: subjectsFuture,
           builder: (context, subjectsSnapshot) {
             if (subjectsSnapshot.connectionState == ConnectionState.waiting) {
               return const Padding(
                 padding: EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
                 child: AppLoadingState(message: 'Loading attendance summary...'),
               );
             }
             final subjects = subjectsSnapshot.data ?? [];
             final overall = overallSnapshot.data;
             final error = overallSnapshot.error?.toString();
             if (subjects.isEmpty && overall == null) {
               return const SizedBox.shrink();
             }
             return Padding(
               padding: const EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
               child: AttendanceSummaryCards(
                 overall: overall,
                 loading: false,
                 error: error,
                 onRetry: () {},
               ),
             );
           },
         );
       },
     );
   }

  /// Short role-specific sentence that introduces the user's module set.
  String _roleSubtitle(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Configure institutional master data and manage students';
      case 'TEACHER':
        return 'Create sessions, mark attendance, and run reports';
      case 'HOD':
        return 'Department analytics, coverage, reports, and teaching your assigned classes';
      case 'STUDENT':
        return 'Track attendance and review your academic profile';
      default:
        return 'Access your attendance, reports, and profile';
    }
  }

  /// Section heading and caption that introduce the module tiles for the
  /// current role without repeating the tile or navigation labels.
  Widget _buildSectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    final role = session.role;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sectionLabel(role),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: DagacsColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _sectionCaption(role),
          style: DagacsTextStyles.caption,
        ),
      ],
    );
  }

  String _sectionLabel(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Command Center';
      case 'TEACHER':
        return 'Attendance & Reporting';
      case 'HOD':
        return 'Department Hub';
      case 'STUDENT':
        return 'Academic Hub';
      default:
        return 'Quick Actions';
    }
  }

  String _sectionCaption(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Configuration and student master';
      case 'TEACHER':
        return 'Sessions, attendance, and exports';
      case 'HOD':
        return 'Analytics, coverage, reports, and teaching';
      default:
        return 'Attendance, reports, and profile';
    }
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
                if (session.email != null && session.role != 'STUDENT') ...[
                  const SizedBox(height: 2),
                  Text(
                    session.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: DagacsSpace.sm),
                Text(
                  _roleSubtitle(role),
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Body tiles. A tile's label duplicates its sidebar entry at desktop widths
  /// (where the shell renders the side navigation), so those titles are
  /// suppressed when the side navigation is visible and restored at tablet and
  /// mobile widths where the drawer is closed and the tile is the only label.
  List<Widget> _buildTiles(BuildContext context, bool sideNavVisible) {
    final role = session.role;
    final tiles = <Widget>[];

    if (role == 'TEACHER') {
      tiles.add(
        AppFeatureTile(
          key: const Key('teacher-my-classes-tile'),
          icon: Icons.class_outlined,
          title: 'My Classes',
          subtitle: 'Your assigned classes with Take Attendance',
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherClasses),
        ),
      );
      tiles.add(
        AppFeatureTile(
          icon: Icons.event_available,
          title: sideNavVisible ? null : 'Attendance',
          subtitle: 'Create sessions and mark student attendance',
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherAttendance),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('teacher-reports-tile'),
          icon: Icons.assignment,
          title: sideNavVisible ? null : 'Reports',
          subtitle: 'Subject-wise attendance report and export',
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherReports),
        ),
      );
    }
    if (role == 'STUDENT') {
      tiles.add(
        AppFeatureTile(
          icon: Icons.how_to_reg,
          title: sideNavVisible ? null : 'My Attendance',
          subtitle: 'View your attendance records',
          onTap: () => Navigator.pushNamed(context, AppRoutes.studentAttendance),
        ),
      );
      tiles.add(
        AppFeatureTile(
          icon: Icons.person_outline,
          title: sideNavVisible ? null : 'My Profile',
          subtitle: 'View your academic profile details',
          onTap: () => Navigator.pushNamed(context, AppRoutes.studentProfile),
        ),
      );
    }
    if (role == 'ADMIN') {
      tiles.add(
        AppFeatureTile(
          key: const Key('admin-master-data-tile'),
          icon: Icons.storage,
          title: sideNavVisible ? null : 'Master Data',
          subtitle:
              'Departments, Programs, Sessions, Semesters, Batches, Sections, Subjects, Offerings',
          onTap: () => Navigator.pushNamed(context, AppRoutes.masterData),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('admin-students-tile'),
          icon: Icons.group,
          title: 'Manage Students',
          subtitle: 'Admin student master - create, edit, activate/deactivate',
          onTap: () => Navigator.pushNamed(context, AppRoutes.adminStudents),
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
          onTap: () => Navigator.pushNamed(context, AppRoutes.hodDashboard),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('hod-reports-tile'),
          icon: Icons.assessment_outlined,
          title: sideNavVisible ? null : 'Reports',
          subtitle:
              'Daily lecture, coverage, rollups, low attendance and exports',
          onTap: () => Navigator.pushNamed(context, AppRoutes.hodReports),
        ),
      );
      tiles.add(
        AppFeatureTile(
          key: const Key('hod-my-classes-tile'),
          icon: Icons.class_outlined,
          title: sideNavVisible ? null : 'My Classes',
          subtitle: 'Your assigned classes with Take Attendance',
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherClasses),
        ),
      );
    }
    return tiles;
  }

}
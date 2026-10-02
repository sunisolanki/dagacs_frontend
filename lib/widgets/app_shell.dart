import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import 'dagacs_widgets.dart';

/// True when [current] is [destination] or a sub-route of it, so module
/// detail pages keep their parent navigation item highlighted.
bool isSameOrChildRoute(String current, String destination) {
  if (current == destination) return true;
  if (destination.length <= 1) return false;
  return current.startsWith('$destination/');
}

/// Exposes the shell's responsive state to its subtree. Page bodies read this
/// to avoid rendering a label the side navigation is already showing, without
/// having to re-derive (or drift from) the shell's own breakpoint.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.sideNavVisible,
    required super.child,
  });

  /// True when the shell renders the persistent side navigation.
  final bool sideNavVisible;

  /// Defaults to false outside an [AppShell], where no side navigation exists.
  static bool sideNavVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppShellScope>()
          ?.sideNavVisible ??
      false;

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      oldWidget.sideNavVisible != sideNavVisible;
}

/// One entry in the role's navigation vocabulary.
///
/// **Phase 5.3** promoted the shell's private list to a shared one so a module
/// screen's drawer shows exactly the destinations the home shell does, instead
/// of a second list that could drift.
class AppDestination {
  const AppDestination(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

/// The navigation destinations available to [role].
///
/// The single source of truth for "where can this role go", shared by [AppShell]
/// and by every module screen's mobile drawer.
List<AppDestination> appDestinationsFor(String role) {
  switch (role) {
    case 'ADMIN':
      return const [
        AppDestination(
            Icons.dashboard_outlined, 'Overview', AppRoutes.home),
        AppDestination(
            Icons.account_tree_outlined, 'Master Data', AppRoutes.masterData),
        AppDestination(
            Icons.people_outline, 'Students', AppRoutes.adminStudents),
      ];
    case 'HOD':
      return const [
        AppDestination(
            Icons.dashboard_outlined, 'Overview', AppRoutes.hodDashboard),
        AppDestination(
            Icons.account_tree_outlined, 'Structure', AppRoutes.hodStructure),
        AppDestination(
            Icons.meeting_room_outlined, 'Sections', AppRoutes.hodSections),
        AppDestination(Icons.book_outlined, 'Subjects', AppRoutes.hodSubjects),
        AppDestination(Icons.people_outline, 'Students', AppRoutes.hodStudents),
        AppDestination(
            Icons.warning_amber_outlined, 'Low Attendance',
            AppRoutes.hodLowAttendance),
        AppDestination(
            Icons.timeline_outlined, 'Rollups', AppRoutes.hodRollups),
        AppDestination(Icons.table_chart_outlined, 'Attendance Matrix',
            AppRoutes.hodAttendanceMatrix),
        AppDestination(
            Icons.assessment_outlined, 'Reports', AppRoutes.hodReports),
        AppDestination(Icons.history, 'Audit Logs', AppRoutes.hodAuditLogs),
        AppDestination(
            Icons.fact_check_outlined, 'My Classes',
            AppRoutes.teacherClasses),
      ];
    case 'TEACHER':
      return const [
        AppDestination(
            Icons.dashboard_outlined, 'Overview', AppRoutes.home),
        AppDestination(
            Icons.fact_check_outlined, 'Attendance',
            AppRoutes.teacherAttendance),
        AppDestination(
            Icons.assignment_outlined, 'Reports', AppRoutes.teacherReports),
      ];
    case 'STUDENT':
    default:
      return const [
        AppDestination(
            Icons.dashboard_outlined, 'Overview', AppRoutes.home),
        AppDestination(
            Icons.how_to_reg_outlined, 'My Attendance',
            AppRoutes.studentAttendance),
        AppDestination(
            Icons.person_outline, 'My Profile', AppRoutes.studentProfile),
      ];
  }
}

/// The authenticated, role-aware application frame used by the home
/// dashboard. It centralizes the navigation vocabulary and deliberately only
/// lists routes supported by the current backend for the signed-in role.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.body,
  });

  final SessionController session;
  final Widget body;

  List<AppDestination> get _destinations => appDestinationsFor(session.role);

  Future<void> _logout(BuildContext context) async {
    await session.clearSession();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _navigate(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current != null && isSameOrChildRoute(current, route)) return;
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final destinations = _destinations;
        final compact = constraints.maxWidth < 480;
        return AppShellScope(
          sideNavVisible: desktop,
          child: Scaffold(
          appBar: AppBar(
            leading: desktop ? null : Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const _BrandTitle(),
            actions: [
              if (!compact)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: DagacsSpace.sm),
                  child: AppRoleChip(role: session.role),
                ),
              Padding(
                padding: const EdgeInsets.only(left: DagacsSpace.md),
                child: AppAvatar(name: session.fullName ?? (session.email != null && session.role != 'STUDENT' ? session.email : null), size: 34),
              ),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout_outlined),
                onPressed: () => _logout(context),
              ),
              const SizedBox(width: DagacsSpace.xs),
            ],
          ),
          drawer: desktop
              ? null
              : Drawer(
                  // Phase 5.8: without this a screen reader announces the panel
                  // only as an unnamed container, so the main way to navigate
                  // on a phone has no accessible name.
                  semanticLabel: 'Navigation menu',
                  child: SafeArea(
                    child: AppNavContent(
                      session: session,
                      destinations: destinations,
                      onNavigate: (route) {
                        Navigator.of(context).pop();
                        _navigate(context, route);
                      },
                      onLogout: () => _logout(context),
                    ),
                  ),
                ),
          body: desktop
              ? Row(
                  children: [
                    SizedBox(
                      width: 244,
                      child: Material(
                        color: DagacsColors.surface,
                        child: AppNavContent(
                          session: session,
                          destinations: destinations,
                          onNavigate: (route) => _navigate(context, route),
                          onLogout: () => _logout(context),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          ),
        );
      },
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Icon(Icons.shield_outlined, color: DagacsColors.brandPrimary),
          SizedBox(width: DagacsSpace.sm),
          Expanded(
            child: Text(
              'DAGACS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

class AppNavContent extends StatelessWidget {
  const AppNavContent({
    required this.session,
    required this.destinations,
    required this.onNavigate,
    required this.onLogout,
  });

  final SessionController session;
  final List<AppDestination> destinations;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    // The destination list is scrollable so a role with many destinations
    // (e.g. HOD) never overflows a short desktop viewport. The user header
    // stays pinned above it and the sign-out action stays pinned below.
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DagacsSpace.lg),
            child: Row(
              children: [
                AppAvatar(name: session.fullName ?? (session.email != null && session.role != 'STUDENT' ? session.email : null), size: 42),
                const SizedBox(width: DagacsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.fullName ?? 'DAGACS user',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(session.email != null && session.role != 'STUDENT' ? session.email! : session.role,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final destination in destinations)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DagacsSpace.sm, vertical: 2),
                    child: ListTile(
                      selected: currentRoute != null &&
                          isSameOrChildRoute(currentRoute, destination.route),
                      selectedTileColor: DagacsColors.brandSoft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DagacsRadius.md)),
                      leading: Icon(destination.icon),
                      title: Text(destination.label),
                      onTap: () => onNavigate(destination.route),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(DagacsSpace.sm),
            child: ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Sign out'),
              onTap: onLogout,
            ),
          ),
        ],
      );
  }
}


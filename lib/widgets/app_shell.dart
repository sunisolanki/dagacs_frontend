import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import 'dagacs_widgets.dart';

/// True when [current] is [destination] or a sub-route of it, so module
/// detail pages keep their parent navigation item highlighted.
bool _isSameOrChildRoute(String current, String destination) {
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

  List<_AppDestination> get _destinations {
    switch (session.role) {
      case 'ADMIN':
        return const [
          _AppDestination(
              Icons.dashboard_outlined, 'Overview', AppRoutes.home),
          _AppDestination(
              Icons.account_tree_outlined, 'Master Data', AppRoutes.masterData),
          _AppDestination(
              Icons.people_outline, 'Students', AppRoutes.adminStudents),
        ];
      case 'HOD':
        return const [
          _AppDestination(
              Icons.dashboard_outlined, 'Overview', AppRoutes.home),
          _AppDestination(
              Icons.insights_outlined, 'Analytics', AppRoutes.hodDashboard),
          _AppDestination(
              Icons.assessment_outlined, 'Reports', AppRoutes.hodReports),
          _AppDestination(
              Icons.fact_check_outlined, 'My Classes',
              AppRoutes.teacherClasses),
        ];
      case 'TEACHER':
        return const [
          _AppDestination(
              Icons.dashboard_outlined, 'Overview', AppRoutes.home),
          _AppDestination(
              Icons.fact_check_outlined, 'Attendance',
              AppRoutes.teacherAttendance),
          _AppDestination(
              Icons.assignment_outlined, 'Reports', AppRoutes.teacherReports),
        ];
      case 'STUDENT':
      default:
        return const [
          _AppDestination(
              Icons.dashboard_outlined, 'Overview', AppRoutes.home),
          _AppDestination(
              Icons.how_to_reg_outlined, 'My Attendance',
              AppRoutes.studentAttendance),
          _AppDestination(
              Icons.person_outline, 'My Profile', AppRoutes.studentProfile),
        ];
    }
  }

  Future<void> _logout(BuildContext context) async {
    await session.clearSession();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _navigate(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current != null && _isSameOrChildRoute(current, route)) return;
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
          drawer: desktop ? null : Drawer(
            child: SafeArea(
              child: _NavContent(
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
                        child: _NavContent(
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

class _NavContent extends StatelessWidget {
  const _NavContent({
    required this.session,
    required this.destinations,
    required this.onNavigate,
    required this.onLogout,
  });

  final SessionController session;
  final List<_AppDestination> destinations;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
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
          for (final destination in destinations)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DagacsSpace.sm, vertical: 2),
              child: ListTile(
                selected: currentRoute != null &&
                    _isSameOrChildRoute(currentRoute, destination.route),
                selectedTileColor: DagacsColors.brandSoft,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DagacsRadius.md)),
                leading: Icon(destination.icon),
                title: Text(destination.label),
                onTap: () => onNavigate(destination.route),
              ),
            ),
          const Spacer(),
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

class _AppDestination {
  const _AppDestination(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

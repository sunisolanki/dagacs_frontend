import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import 'app_shell.dart';

/// Phase 5.3: the navigation frame a module screen sits inside.
///
/// **The problem it solves.** The application shell that hosts the home screen
/// has always had a role-aware drawer, but it was only ever applied to the home
/// screen itself. Every module screen below it - student attendance, teacher
/// marking, admin student management - was a bare [Scaffold] whose only way out
/// was the system back button. On a phone, where back is a gesture rather than a
/// visible control, that is not navigation a user can rely on.
///
/// **Why it is a wrapper and not a new shell.** The drawer's contents are
/// [AppNavContent] and the destination list is [appDestinationsFor] - the very
/// same ones the home shell uses. A second navigation list would be a second
/// thing to keep in step with the role model, and would eventually disagree with
/// what the drawer on the home screen offers. This adds a frame, not a system.
///
/// **Desktop is untouched.** At the shell's own 1024 dp breakpoint and above,
/// this renders exactly the [Scaffold] the screen was rendering before: the
/// screen's own [AppBar], its own actions, no drawer, no hamburger. Nothing
/// about the desktop or web layout changes.
class AppModuleScaffold extends StatelessWidget {
  const AppModuleScaffold({
    super.key,
    required this.session,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.leading,
    this.showTitle = true,
  });

  final SessionController session;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Replaces the default back arrow, e.g. to open a detail from a sheet.
  final Widget? leading;

  /// False hides the title text, keeping the bar height - used by screens whose
  /// body already carries a page title.
  final bool showTitle;

  /// The shell's own desktop breakpoint, so both frames agree on where the
  /// persistent navigation starts.
  static const double desktopBreakpoint = 1024;

  Future<void> _logout(BuildContext context) async {
    await session.clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
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
        final wide = constraints.maxWidth >= desktopBreakpoint;

        return Scaffold(
          appBar: AppBar(
            leading: wide
                ? leading
                : Builder(
                    builder: (context) => IconButton(
                      // The same affordance the home shell offers, so the two
                      // are recognisably the same navigation.
                      tooltip: 'Open navigation',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            title: showTitle ? Text(title) : null,
            actions: actions,
          ),
          // Only a narrow screen gets a drawer. Adding one above the breakpoint
          // would put navigation on the desktop layout that has never had it.
          drawer: wide
              ? null
              : Drawer(
                    // Phase 5.8: see app_shell.dart - the drawer's accessible
                    // name comes from the Drawer itself, not a wrapper.
                    semanticLabel: 'Navigation menu',
                    child: SafeArea(
                    child: AppNavContent(
                      session: session,
                      destinations: appDestinationsFor(session.role),
                      onNavigate: (route) {
                        Navigator.of(context).pop();
                        _navigate(context, route);
                      },
                      onLogout: () => _logout(context),
                    ),
                  ),
                ),
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
        );
      },
    );
  }
}

/// The small labelled destination tiles the home screen uses.
///
/// Exposed so a module screen can offer the same affordance in its own body
/// without reaching for a private widget.
class AppModuleHeader extends StatelessWidget {
  const AppModuleHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: DagacsSpace.xs),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';

/// Landing page for unknown/malformed routes (M9.5.4).
///
/// Keeps the user inside the app shell and offers a single clear path back to
/// Home. This prevents blank-screen dead ends when a deep link, browser
/// address-bar typo, or post-logout redirect lands on a nonexistent route.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(DagacsSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIconBadge(
                    icon: Icons.explore_off_outlined,
                    color: DagacsColors.textSecondary,
                    backgroundColor: DagacsColors.surfaceAlt,
                    size: 64,
                  ),
                  const SizedBox(height: DagacsSpace.lg),
                  Text(
                    'Page not found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: DagacsSpace.sm),
                  Text(
                    'The page you tried to reach does not exist or has been '
                    'moved.',
                    textAlign: TextAlign.center,
                    style: DagacsTextStyles.body
                        .copyWith(color: DagacsColors.textSecondary),
                  ),
                  const SizedBox(height: DagacsSpace.xl),
                  AppPrimaryButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
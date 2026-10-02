import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 5.12 guard (authored in 5.7): "every reachable module screen has a
/// way back" is only a real requirement if it is *checkable*. This test encodes
/// the classification so a future screen cannot silently join the app without
/// either adopting the shared shell or being deliberately classified as a
/// sub-flow.
///
/// The rule:
///   * Top-level module screens join the shared navigation shell.
///   * Screens pushed on top of another route do not - they inherit the back
///     button, and giving a modal sub-flow its own drawer would let a user
///     navigate away from unsaved form state.
///   * Root screens (auth, splash, not-found, home) are exempt: a drawer would
///     be meaningless before there is a session, and home *is* the shell.
void main() {
  final screensDir = Directory('lib/screens');

  List<File> dartFilesUnder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  bool uses(File f, String needle) => f.readAsStringSync().contains(needle);

  /// Screens deliberately excluded, with the reason.
  const exempt = <String, String>{
    // Root / pre-session. A drawer here would offer destinations the user
    // cannot reach yet.
    'splash_screen.dart': 'root, no session yet',
    'login_screen.dart': 'root, pre-authentication',
    'change_password_screen.dart': 'forced root flow, no destination to lose',
    'not_found_screen.dart': 'terminal error page',
    // The shell itself.
    'home_screen.dart': 'uses AppShell directly - it IS the shell',
    // Pushed sub-flows: they inherit the AppBar back button from the route
    // that pushed them.
    'create_session_screen.dart': 'pushed sub-flow of Attendance Sessions',
    'mark_attendance_screen.dart': 'pushed sub-flow of Attendance Sessions',
  };

  /// Everything under lib/screens/master_data is pushed from the Master Data
  /// hub, so the whole directory is sub-flow by construction.
  bool isMasterDataSubFlow(File f) =>
      f.path.replaceAll('\\', '/').contains('lib/screens/master_data/');

  test('every top-level module screen adopts the shared navigation shell',
      () {
    final offenders = <String>[];

    for (final file in dartFilesUnder(screensDir.path)) {
      final rel = file.path.replaceAll('\\', '/').split('/').last;
      if (rel.startsWith('app_module_scaffold')) continue;

      if (uses(file, 'AppModuleScaffold(') || uses(file, 'HodScaffold(')) {
        continue;
      }
      if (exempt.containsKey(rel)) continue;
      if (isMasterDataSubFlow(file)) continue;

      offenders.add(file.path.replaceAll('\\', '/'));
    }

    expect(offenders, isEmpty,
        reason: 'These screens are neither on the shared shell nor classified '
            'as exempt or as pushed sub-flows. Add one of those categories so '
            'the classification stays honest:\n${offenders.join('\n')}');
  });

  test('the exempt list still refers to screens that exist', () {
    // A stale exemption would let a real screen drift out of coverage without
    // anyone noticing, so the names must keep resolving.
    final present = dartFilesUnder(screensDir.path)
        .map((f) => f.path.replaceAll('\\', '/').split('/').last)
        .toSet();
    final stale = exempt.keys.where((name) => !present.contains(name)).toList();
    expect(stale, isEmpty,
        reason: 'these exemptions name files that no longer exist: $stale');
  });

  test('the exempt screens still contain no shared shell by accident', () {
    // If an exempt screen later adopts the shell, the exemption must be
    // removed rather than left to mask a real classification change.
    final drift = <String>[];
    for (final file in dartFilesUnder(screensDir.path)) {
      final rel = file.path.replaceAll('\\', '/').split('/').last;
      if (!exempt.containsKey(rel)) continue;
      if (rel == 'home_screen.dart') continue; // uses AppShell by design
      if (uses(file, 'AppModuleScaffold(') || uses(file, 'HodScaffold(')) {
        drift.add(rel);
      }
    }
    expect(drift, isEmpty,
        reason: 'these screens now adopt the shared shell but are still listed '
            'as exempt: $drift');
  });
}
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';

/// Shows during startup while the persisted session is being restored.
/// Routes to /login (unauthenticated) or /home (authenticated).
///
/// **Phase 5.2 - the splash can no longer hang.** Restoring the session reads the
/// JWT from the platform secure store, and that read has no completion guarantee:
/// a wedged keystore, a missing plugin, or a slow device could leave the app on a
/// spinner forever with no way forward. Restoration is therefore bounded by
/// [restoreTimeout], and the failure mode is **fail-closed**: an unresolvable
/// session is treated as no session, the stored credential is discarded, and the
/// user is sent to the login screen with an explanation and a Retry, rather than
/// being stranded or - worse - being let in on a session we could not verify.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.session, this.restoreTimeout});

  final SessionController session;

  /// Upper bound on session restoration. Overridable so a test can prove the
  /// timeout path without waiting in real time.
  final Duration? restoreTimeout;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Generous for a real keystore read, and short enough that a wedged store
  /// still gets the user to a login screen rather than an indefinite spinner.
  static const Duration defaultTimeout = Duration(seconds: 5);

  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    // Only reset the failure banner on a *retry*. During the first call this
    // runs synchronously inside initState, where setState is not allowed - the
    // banner is already false at that point anyway.
    if (_timedOut && mounted) {
      setState(() => _timedOut = false);
    }
    final budget = widget.restoreTimeout ?? defaultTimeout;
    try {
      await widget.session.restoreSession().timeout(budget);
    } on TimeoutException {
      // The store is slow, not broken. The session may well be valid, so the
      // user is offered a Retry rather than being logged out - but they are NOT
      // let in on a session we could not verify, and they are not stranded.
      if (!mounted) return;
      setState(() => _timedOut = true);
      return;
    } catch (_) {
      // Restoration is impossible, not merely slow - a missing plugin or an
      // unreadable store. Retrying cannot help, so the credential is discarded
      // and the user goes straight to the login screen, where a fresh login can
      // still succeed.
      await _discardUnverifiableSession();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context, widget.session.isAuthenticated ? '/home' : '/login');
  }

  /// Clears a session that could not be verified, so a later attempt starts clean.
  Future<void> _discardUnverifiableSession() async {
    try {
      await widget.session.clearSession();
    } catch (_) {
      // Nothing further to do: the app is already routing to login, and the
      // backend remains the authority on every request regardless.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 96, color: Color(0xFF1A73E8)),
            const SizedBox(height: 24),
            if (_timedOut) ...[
              const Text(
                'Could not restore your session.',
                key: Key('splash-restore-failed'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('splash-retry'),
                onPressed: _restore,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('splash-go-to-login'),
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Continue to sign in'),
              ),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

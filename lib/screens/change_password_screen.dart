import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../network/api_exception.dart';
import '../repositories/student_management_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// Forced first-login password change screen (M10A).
///
/// Shown automatically after login when [mustChangePassword] is true.
/// The student must verify the current password and set a new one; on success
/// the session is kept (no logout) and the student continues into the app.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final SessionController session;
  final StudentManagementRepository repository;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final newPassword = _passwordController.text.trim();
    if (newPassword != _confirmController.text.trim()) {
      setState(() {
        _error = 'Passwords do not match.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.repository.changePassword(
        currentPassword: _currentController.text.trim(),
        newPassword: newPassword,
        confirmPassword: _confirmController.text.trim(),
      );
      if (!mounted) return;
      await widget.session.completePasswordChange();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Welcome to DAGACS.'),
        ),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FAFD),
              Color(0xFFEAF2FA),
              Color(0xFFE5F1EF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  DagacsSpace.xl,
                  DagacsSpace.xl,
                  DagacsSpace.xl,
                  DagacsSpace.xl +
                      MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? 1000 : 420,
                    ),
                    child: wide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _buildBrandPanel()),
                                const SizedBox(width: DagacsSpace.xxl),
                                SizedBox(
                                  width: 380,
                                  child: _buildChangePasswordCard(),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBrandHeader(),
                              const SizedBox(height: DagacsSpace.xxl),
                              _buildChangePasswordCard(),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield_outlined, size: 72, color: DagacsColors.brandPrimary),
        SizedBox(height: DagacsSpace.md),
        Text('DAGACS', style: DagacsTextStyles.display),
        SizedBox(height: DagacsSpace.sm),
        Text(
          'Department Attendance Governance, Analytics and Compliance System',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: DagacsColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      padding: const EdgeInsets.all(DagacsSpace.xxxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DagacsColors.brandPrimary,
            DagacsColors.brandDark,
            DagacsColors.brandDark,
          ],
        ),
        borderRadius: BorderRadius.circular(DagacsRadius.xl + 4),
        boxShadow: DagacsColors.cardShadow,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield, size: 72, color: Colors.white),
          SizedBox(height: DagacsSpace.xl),
          Text(
            'DAGACS',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          SizedBox(height: DagacsSpace.sm),
          Text(
            'Department Attendance Governance, Analytics and Compliance System',
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white70),
          ),
          SizedBox(height: DagacsSpace.xxxl),
          _BrandFeature(
            icon: Icons.security_outlined,
            text: 'First-login security requires a password change',
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(DagacsSpace.xxl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DagacsRadius.xl),
          boxShadow: DagacsColors.dialogShadow,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset, size: 48, color: DagacsColors.brandPrimary),
              const SizedBox(height: DagacsSpace.md),
              Text(
                'Change Your Password',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: DagacsSpace.xs),
              Text(
                'This is your first login. Verify your current password and set a new one.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: DagacsSpace.lg),
              AppFormTextField(
                key: const Key('field-current-password'),
                label: 'Current Password',
                controller: _currentController,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Current password is required';
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              AppFormTextField(
                key: const Key('field-new-password'),
                label: 'New Password',
                controller: _passwordController,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outlined,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Password is required';
                  }
                  if (value.trim().length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              AppFormTextField(
                key: const Key('field-confirm-password'),
                label: 'Confirm Password',
                controller: _confirmController,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: DagacsSpace.xs),
                Container(
                  padding: const EdgeInsets.all(DagacsSpace.md),
                  decoration: BoxDecoration(
                    color: DagacsColors.errorBg,
                    borderRadius: BorderRadius.circular(DagacsRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: DagacsColors.error),
                      const SizedBox(width: DagacsSpace.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: DagacsColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: DagacsSpace.lg),
              AppPrimaryButton(
                onPressed: _submit,
                loading: _isLoading,
                child: const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(width: DagacsSpace.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
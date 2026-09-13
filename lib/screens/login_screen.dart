import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../network/api_exception.dart';
import '../repositories/auth_repository.dart';
import '../widgets/dagacs_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key, required this.authRepository, required this.session});

  final AuthRepository authRepository;
  final SessionController session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = await widget.authRepository
          .login(_identifierController.text.trim(), _passwordController.text);
      await widget.authRepository.persistSession(auth);
      widget.session.establishSession(
        auth.role ?? 'STUDENT',
        email: auth.email,
        fullName: auth.fullName,
        mustChangePassword: auth.mustChangePassword,
      );
      if (!mounted) return;
      if (auth.role == 'STUDENT' && auth.mustChangePassword) {
        Navigator.pushReplacementNamed(context, AppRoutes.studentChangePassword);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 401 ? 'Invalid email or password.' : userMessageFor(e);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Login failed. Please try again.';
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
                                  child: _buildLoginCard(),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBrandHeader(),
                              const SizedBox(height: DagacsSpace.xxl),
                              _buildLoginCard(),
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
            icon: Icons.fact_check_outlined,
            text: 'Attendance governance for the whole department',
          ),
          SizedBox(height: DagacsSpace.lg),
          _BrandFeature(
            icon: Icons.admin_panel_settings_outlined,
            text: 'Role-aware access for admin, HOD, teachers and students',
          ),
          SizedBox(height: DagacsSpace.lg),
          _BrandFeature(
            icon: Icons.analytics_outlined,
            text: 'Compliance analytics and exportable reports',
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
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
              Text('Welcome back', style: theme.textTheme.titleLarge),
              const SizedBox(height: DagacsSpace.xs),
              Text(
                'Sign in to your DAGACS account',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: DagacsSpace.xl),
              AppFormTextField(
                key: const Key('login-identifier'),
                label: 'Roll Number or Email',
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                autofocus: true,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Roll number or email is required';
                  }
                  return null;
                },
              ),
              AppFormTextField(
                key: const Key('login-password'),
                label: 'Password',
                controller: _passwordController,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                autofocus: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
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
                onPressed: _handleLogin,
                loading: _isLoading,
                child: const Text('Sign In'),
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
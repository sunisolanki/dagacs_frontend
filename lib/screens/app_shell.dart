import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShell extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const AppShell({required this.navigatorKey, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _role = 'STUDENT';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _role = prefs.getString('user_role') ?? 'STUDENT');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('access_token');
    if (!mounted) return;
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DAGACS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: _buildRoleSpecificContent(),
      ),
    );
  }

  Widget _buildRoleSpecificContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.shield, size: 64, color: Color(0xFF1A73E8)),
        const SizedBox(height: 16),
        Text(
          'Welcome, $_role',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A73E8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'M1 Placeholder',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Role-specific dashboard - M1 placeholder',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
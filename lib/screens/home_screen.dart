import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../repositories/master_data_repository.dart';

/// Authenticated home. Role-aware welcome plus entry to the master-data API
/// demonstration (admin-only on the backend; other roles see an informational
/// message / graceful 403 handling).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.masterDataRepository,
  });

  final SessionController session;
  final MasterDataRepository masterDataRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DAGACS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.shield, size: 64, color: Color(0xFF1A73E8)),
          const SizedBox(height: 16),
          Text(
            'Welcome, ${session.fullName ?? session.role}',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Role: ${session.role}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (session.email != null)
            Text(
              session.email!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Master Data'),
              subtitle: const Text(
                  'Departments, Programs, Sessions, Semesters, Batches, Sections, Subjects'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/master-data'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await session.clearSession();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}

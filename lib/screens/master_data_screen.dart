import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../network/api_exception.dart';
import '../repositories/master_data_repository.dart';

/// Demonstrates consuming the real master-data hierarchy from the backend:
/// Department -> Program -> AcademicSession -> (Semester | Batch) -> Section,
/// plus the flat Subject list.
///
/// The backend protects these endpoints for ADMIN only. For non-admin roles the
/// request maps to 403 and this screen shows a graceful access-denied message
/// (backend authorization is authoritative; nothing is faked on the client).
class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen(
      {super.key, required this.repository, required this.session});

  final MasterDataRepository repository;
  final SessionController session;

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final departments = await widget.repository.getDepartments();
      final programs = await widget.repository.getPrograms();
      final sessions = await widget.repository.getAcademicSessions();
      final semesters = await widget.repository.getSemesters();
      final batches = await widget.repository.getBatches();
      final sections = await widget.repository.getSections();
      final subjects = await widget.repository.getSubjects();
      if (!mounted) return;
      setState(() {
        _data = {
          'Departments': departments.length,
          'Programs': programs.length,
          'Academic Sessions': sessions.length,
          'Semesters': semesters.length,
          'Batches': batches.length,
          'Sections': sections.length,
          'Subjects': subjects.length,
        };
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading master data.';
        _loading = false;
      });
    }
  }

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Data')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final entries = _data!.entries.toList();
    return RefreshIndicator(
      key: const Key('master-data-refresh'),
      onRefresh: _load,
      child: entries.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: const Center(child: Text('No master data available.')),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(entry.key),
                  trailing: Text('${entry.value}',
                      style: Theme.of(context).textTheme.titleMedium),
                );
              },
            ),
    );
  }
}

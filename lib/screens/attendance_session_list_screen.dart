import 'package:flutter/material.dart';

import '../models/attendance_session.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';

/// Teacher's attendance session list. Shows all sessions owned by the
/// authenticated teacher (resolved from JWT by the backend).
class AttendanceSessionListScreen extends StatefulWidget {
  const AttendanceSessionListScreen(
      {super.key, required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  State<AttendanceSessionListScreen> createState() =>
      _AttendanceSessionListScreenState();
}

class _AttendanceSessionListScreenState
    extends State<AttendanceSessionListScreen> {
  bool _loading = true;
  String? _error;
  List<AttendanceSession> _sessions = [];

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
      final sessions = await widget.attendanceRepository.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
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
        _error = 'Something went wrong while loading sessions.';
        _loading = false;
      });
    }
  }

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'SCHEDULED':
        return Colors.orange;
      case 'CONDUCTED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Sessions')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create session',
        onPressed: () async {
          await Navigator.pushNamed(context, '/teacher/attendance/create');
          _load();
        },
        child: const Icon(Icons.add),
      ),
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
    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No attendance sessions yet.'),
                  const SizedBox(height: 8),
                  const Text('Tap + to create one.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final s = _sessions[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(
                  '${s.subjectName ?? "Subject ${s.subjectId ?? "-"}"} - ${s.sectionName ?? "Section ${s.sectionId ?? "-"}"}'),
              subtitle: Text(
                  '${s.date ?? "-"} | ${s.lecturePeriod ?? "-"}'),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(s.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.status ?? '?',
                  style: TextStyle(
                    color: _statusColor(s.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              onTap: () {
                if (s.id != null) {
                  Navigator.pushNamed(context, '/teacher/attendance/mark',
                      arguments: s.id);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

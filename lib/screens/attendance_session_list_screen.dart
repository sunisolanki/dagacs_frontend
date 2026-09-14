import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/theme/dagacs_theme.dart';
import '../models/attendance_session.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../widgets/dagacs_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Sessions')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create session',
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.createSession);
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading attendance sessions...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
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
                children: const [
                  AppEmptyState(
                    icon: Icons.event_available_outlined,
                    message: 'No attendance sessions yet.',
                  ),
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
        padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg,
          DagacsSpace.md,
          DagacsSpace.lg,
          96,
        ),
        itemBuilder: (context, index) {
          final s = _sessions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
            child: AppCard(
              onTap: s.id == null
                  ? null
                  : () => Navigator.pushNamed(
                        context,
                        AppRoutes.markAttendance,
                        arguments: s.id,
                      ),
              child: Row(
                children: [
                  const AppIconBadge(icon: Icons.event_note_outlined),
                  const SizedBox(width: DagacsSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.subjectName ?? "Subject ${s.subjectId ?? "-"}"} · '
                          '${s.sectionName != null && s.sectionName!.isNotEmpty ? s.sectionName : (s.batchName != null && s.batchName!.isNotEmpty ? s.batchName : "Section ${s.sectionId ?? "-"}")}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: DagacsSpace.xs),
                        Text('${s.date ?? "-"} · ${s.lecturePeriod ?? "-"}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: DagacsSpace.sm),
                  AppStatusBadge(
                    label: s.status ?? 'UNKNOWN',
                    active: s.status == 'CONDUCTED',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

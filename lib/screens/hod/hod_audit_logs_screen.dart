import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../models/hod_audit_log_entry.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_repository.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Attendance correction history, migrated from the previous HOD dashboard's
/// "Audit Logs" tab onto its own route.
///
/// Records come exclusively from the backend's real audit log; no entry is
/// ever synthesised client-side.
class HodAuditLogsScreen extends StatefulWidget {
  const HodAuditLogsScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;

  @override
  State<HodAuditLogsScreen> createState() => _HodAuditLogsScreenState();
}

class _HodAuditLogsScreenState extends State<HodAuditLogsScreen> {
  static const String _errorCopy = 'Failed to load audit logs.';

  bool _loading = true;
  String? _error;
  List<HodAuditLogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.hodRepository.getAuditLogs(
        startDate: widget.academicContext.startDate,
        endDate: widget.academicContext.endDate,
      );
      if (!mounted) return;
      setState(() {
        _entries = data;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _error = _errorCopy;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _errorCopy;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'Audit Logs',
      subtitle: 'Attendance corrections recorded in your department.',
      icon: Icons.history,
      onRangeChanged: _load,
      body: HodListPanel(
        loading: _loading,
        errorMessage: _error,
        onRetry: _load,
        emptyMessage: 'No audit log entries yet.',
        loadingMessage: 'Loading audit logs...',
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final e = _entries[index];
          final previous = e.previousStatus ?? '-';
          final next = e.newStatus ?? '-';
          return ListTile(
            leading: const Icon(Icons.history, color: Colors.orange),
            title: Text(
              '${e.studentName ?? 'Student'}  (${e.rollNo ?? '-'})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${e.subjectName ?? '-'} | ${e.sectionName ?? '-'} | ${e.date ?? '-'}'),
                Text('$previous \u2192 $next'),
                if (e.updatedBy != null || e.updatedAt != null)
                  Text('By ${e.updatedBy ?? '-'} at ${e.updatedAt ?? '-'}'),
                if (e.reason != null && e.reason!.isNotEmpty)
                  Text('Reason: ${e.reason}'),
              ],
            ),
          );
        },
      ),
    );
  }
}

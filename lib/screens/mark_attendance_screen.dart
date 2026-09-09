import 'package:flutter/material.dart';

import '../models/attendance_mark_item.dart';
import '../models/attendance_mark_request.dart';
import '../models/attendance_update_request.dart';
import '../models/session_student.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';

/// Screen for marking or updating attendance for a single session.
///
/// Students without an existing record start as UNMARKED (local UI state).
/// Every student must be explicitly set to PRESENT or ABSENT before
/// submission. UNMARKED is never sent to the backend.
///
/// Students with existing records use PUT per-record.
/// Students without existing records use batch POST.
/// CANCELLED sessions block all marking.
class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({
    super.key,
    required this.sessionId,
    required this.attendanceRepository,
  });

  final int sessionId;
  final AttendanceRepository attendanceRepository;

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<SessionStudent> _students = [];
  Map<int, String> _statusMap = {}; // studentId -> PRESENT / ABSENT / null (UNMARKED)
  Map<int, String> _persistedStatusMap = {}; // studentId -> last-known backend PRESENT / ABSENT
  Map<int, int> _existingRecordIds = {}; // studentId -> backend record ID
  bool _sessionCancelled = false;

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
      // Fetch session status via existing getSessions endpoint.
      final sessions =
          await widget.attendanceRepository.getSessions();
      final session = sessions
          .where((s) => s.id == widget.sessionId)
          .toList();
      if (session.isNotEmpty && session.first.status == 'CANCELLED') {
        if (!mounted) return;
        setState(() {
          _sessionCancelled = true;
          _loading = false;
        });
        return;
      }

      final students =
          await widget.attendanceRepository.getStudentsForSession(widget.sessionId);

      // Do NOT swallow errors from getRecordsForSession.
      // HTTP 200 + [] means no records yet (normal).
      // 403/404/500/network errors must surface.
      final records = await widget.attendanceRepository
          .getRecordsForSession(widget.sessionId);

      final statusMap = <int, String>{};
      final persistedStatusMap = <int, String>{};
      final existingRecordIds = <int, int>{};

      for (final student in students) {
        if (student.id != null) {
          final existing =
              records.where((r) => r.studentId == student.id).toList();
          if (existing.isNotEmpty) {
            final r = existing.first;
            existingRecordIds[student.id!] = r.id!;
            if (r.status == 'PRESENT' || r.status == 'ABSENT') {
              statusMap[student.id!] = r.status!;
              persistedStatusMap[student.id!] = r.status!;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _statusMap = statusMap;
        _persistedStatusMap = persistedStatusMap;
        _existingRecordIds = existingRecordIds;
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
        _error = 'Something went wrong while loading attendance data.';
        _loading = false;
      });
    }
  }

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  void _toggleStatus(int studentId) {
    setState(() {
      final current = _statusMap[studentId];
      if (current == null) {
        // UNMARKED -> PRESENT
        _statusMap[studentId] = 'PRESENT';
      } else if (current == 'PRESENT') {
        // PRESENT -> ABSENT
        _statusMap[studentId] = 'ABSENT';
      } else {
        // ABSENT -> UNMARKED (remove from map)
        _statusMap.remove(studentId);
      }
    });
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'PRESENT':
        return 'Present';
      case 'ABSENT':
        return 'Absent';
      default:
        return 'Unmarked';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'PRESENT':
        return Icons.check_circle;
      case 'ABSENT':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _submit() async {
    if (_sessionCancelled) return;

    // Validate: every student must be explicitly marked.
    final unmarked =
        _students.where((s) => s.id != null && !_statusMap.containsKey(s.id));
    if (unmarked.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mark attendance for all students.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    // Split into existing (PUT) and new (batch POST).
    final newItems = <AttendanceMarkItem>[];
    String? putError;

    for (final student in _students) {
      final sid = student.id;
      if (sid == null) continue;
      final newStatus = _statusMap[sid]!;

      if (_existingRecordIds.containsKey(sid)) {
        // Existing record: use PUT.
        final recordId = _existingRecordIds[sid]!;
        try {
          final updatedRecord = await widget.attendanceRepository
              .updateAttendance(
                  recordId, AttendanceUpdateRequest(newStatus: newStatus));
          if (!mounted) return;
          setState(() {
            _statusMap[sid] = updatedRecord.status!;
            _persistedStatusMap[sid] = updatedRecord.status!;
            _existingRecordIds[sid] = updatedRecord.id!;
          });
        } catch (e) {
          // Revert to last-known persisted backend state.
          if (!mounted) return;
          setState(() {
            if (_persistedStatusMap.containsKey(sid)) {
              _statusMap[sid] = _persistedStatusMap[sid]!;
            } else {
              _statusMap.remove(sid);
            }
          });
          putError = e is ApiException
              ? userMessageFor(e)
              : 'Failed to update attendance for ${student.name ?? "student"}.';
          break; // Stop processing further updates on failure.
        }
      } else {
        // New record: will use batch POST.
        newItems.add(AttendanceMarkItem(studentId: sid, status: newStatus));
      }
    }

    // If any PUT update failed, show SnackBar and stop.
    if (putError != null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(putError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Batch POST only new records.
      if (newItems.isNotEmpty) {
        final createdRecords = await widget.attendanceRepository.markAttendance(
          AttendanceMarkRequest(
            sessionId: widget.sessionId,
            items: newItems,
          ),
        );

        if (!mounted) return;
        for (final r in createdRecords) {
          if (r.studentId != null && r.id != null) {
            setState(() {
              _existingRecordIds[r.studentId!] = r.id!;
              _statusMap[r.studentId!] = r.status!;
            });
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.statusCode == 409
            ? 'Cannot mark attendance on a cancelled session or duplicate record.'
            : userMessageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Failed to submit attendance. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          if (!_loading && !_sessionCancelled && _students.isNotEmpty)
            TextButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SUBMIT'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading students...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_sessionCancelled) {
      return const AppEmptyState(
        icon: Icons.cancel_outlined,
        message: 'This session is cancelled. Attendance cannot be marked.',
      );
    }
    if (_students.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        message: 'No students are available for this session.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _students.length,
              padding: const EdgeInsets.symmetric(
                  horizontal: DagacsSpace.lg, vertical: DagacsSpace.md),
              itemBuilder: (context, index) {
                final student = _students[index];
                final studentId = student.id;
                final status =
                    studentId != null ? _statusMap[studentId] : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
                  child: AppCard(
                    child: Row(
                      children: [
                        AppIconBadge(
                          icon: _statusIcon(status),
                          color: status == 'ABSENT'
                              ? DagacsColors.error
                              : status == 'PRESENT'
                                  ? DagacsColors.success
                                  : DagacsColors.textSecondary,
                          backgroundColor: status == 'ABSENT'
                              ? DagacsColors.errorBg
                              : status == 'PRESENT'
                                  ? DagacsColors.successBg
                                  : DagacsColors.surfaceAlt,
                        ),
                        const SizedBox(width: DagacsSpace.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name ?? 'Unknown',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: DagacsSpace.xs),
                              Text(student.rollNumber ?? 'No roll number',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Change ${student.name ?? 'student'} attendance status',
                          child: TextButton(
                            onPressed: studentId != null && !_submitting
                                ? () => _toggleStatus(studentId)
                                : null,
                            child: AppStatusBadge(
                              label: _statusLabel(status),
                              active: status == 'PRESENT',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

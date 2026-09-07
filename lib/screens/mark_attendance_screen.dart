import 'package:flutter/material.dart';

import '../models/attendance_mark_item.dart';
import '../models/attendance_mark_request.dart';
import '../models/attendance_update_request.dart';
import '../models/session_student.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';

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
    switch (e.statusCode) {
      case 403:
        return 'You are not authorized for this session.';
      case 404:
        return 'Session not found.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'PRESENT':
        return Colors.green;
      case 'ABSENT':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
              ? e.message
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
        _error = switch (e.statusCode) {
          409 =>
            'Cannot mark attendance on a cancelled session or duplicate record.',
          -1 => 'Network error. Check your connection and try again.',
          _ => e.message,
        };
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
    if (_sessionCancelled) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This session is cancelled. Attendance cannot be marked.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No students found for this session.'),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final studentId = student.id;
                final status =
                    studentId != null ? _statusMap[studentId] : null;

                return ListTile(
                  leading: Icon(_statusIcon(status),
                      color: _statusColor(status)),
                  title: Text(student.name ?? 'Unknown'),
                  subtitle: Text(student.rollNumber ?? '-'),
                  trailing: GestureDetector(
                    onTap: studentId != null && !_sessionCancelled
                        ? () => _toggleStatus(studentId)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _statusColor(status)),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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

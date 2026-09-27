import 'package:flutter/material.dart';

import '../models/attendance_mark_item.dart';
import '../models/attendance_mark_request.dart';
import '../models/attendance_update_request.dart';
import '../models/session_student.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';

/// Tri-state of the "Select All" control, mirroring how a partially marked
/// roster should read.
enum SelectAllState { all, some, none }

/// Screen for marking or updating attendance for a single session.
///
/// Students without an existing record start as UNMARKED (local UI state).
/// UNMARKED students submitted as-is default to ABSENT. UNMARKED is never
/// sent to the backend; the submit loop resolves it to ABSENT on the client.
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

  // ── Derived roster metrics ──────────────────────────────────────────────
  // Counters are computed over the *markable* roster, never the raw row count.
  // A student without an id is skipped by _submit (`if (sid == null) continue;`)
  // and its toggle is disabled, so it must not be reported as Unmarked. Because
  // all three buckets filter on `s.id != null`, they partition one set and
  // present + absent + unmarked == _markableCount holds by construction.

  /// Students that can actually receive a mark.
  int get _markableCount => _students.where((s) => s.id != null).length;

  int get _presentCount => _students
      .where((s) => s.id != null && _statusMap[s.id] == 'PRESENT')
      .length;

  int get _absentCount => _students
      .where((s) => s.id != null && _statusMap[s.id] == 'ABSENT')
      .length;

  int get _unmarkedCount => _markableCount - _presentCount - _absentCount;

  bool get _allMarkedPresent =>
      _markableCount > 0 && _presentCount == _markableCount;

  bool get _noneMarkedPresent => _presentCount == 0;

  /// Tri-state so a partially marked roster is visible in the control itself.
  SelectAllState get _selectAllState {
    if (_allMarkedPresent) return SelectAllState.all;
    if (_noneMarkedPresent) return SelectAllState.none;
    return SelectAllState.some;
  }

  /// Bulk Present/Restore.
  ///
  /// Selecting is monotonic: it only ever adds a PRESENT mark. Deselecting does
  /// NOT clear the roster to Unmarked - that would combine with _submit's
  /// `_statusMap[sid] ?? 'ABSENT'` and silently rewrite a persisted Present
  /// roster to Absent. Instead it restores the backend-confirmed baseline held
  /// in _persistedStatusMap, so every student's effective submit status after
  /// a select/deselect round trip is identical to before it.
  void _toggleSelectAll() {
    if (_submitting) return;
    setState(() {
      if (_allMarkedPresent) {
        for (final student in _students) {
          final sid = student.id;
          if (sid == null) continue;
          final persisted = _persistedStatusMap[sid];
          if (persisted != null) {
            _statusMap[sid] = persisted;
          } else {
            // No confirmed record: back to Unmarked, which _submit resolves to
            // ABSENT exactly as it does today.
            _statusMap.remove(sid);
          }
        }
      } else {
        for (final student in _students) {
          final sid = student.id;
          if (sid != null) _statusMap[sid] = 'PRESENT';
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_sessionCancelled) return;

    setState(() => _submitting = true);

    // Split into existing (PUT) and new (batch POST).
    // UNMARKED students default to ABSENT (kept local; the backend only
    // ever receives explicit PRESENT/ABSENT records).
    final newItems = <AttendanceMarkItem>[];
    String? putError;

    for (final student in _students) {
      final sid = student.id;
      if (sid == null) continue;
      final newStatus = _statusMap[sid] ?? 'ABSENT';

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
        _buildSummaryHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _students.length,
              padding: const EdgeInsets.fromLTRB(
                DagacsSpace.lg,
                DagacsSpace.xs,
                DagacsSpace.lg,
                // Reserve room for the sticky footer so the last row is never
                // hidden behind it.
                96,
              ),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
                  child: _buildStudentTile(_students[index]),
                );
              },
            ),
          ),
        ),
        _buildStickyFooter(),
      ],
    );
  }

  /// Compact metrics strip: roster size, live Present/Absent/Unmarked counts
  /// and the bulk Select All control.
  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg, DagacsSpace.md, DagacsSpace.lg, DagacsSpace.md),
      decoration: const BoxDecoration(
        color: DagacsColors.surface,
        border: Border(
          bottom: BorderSide(color: DagacsColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Flexible so the roster label yields space to the Select All
              // control on narrow phones instead of overflowing.
              Expanded(
                child: Text(
                  '$_markableCount ${_markableCount == 1 ? 'Student' : 'Students'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: DagacsSpace.sm),
              _buildSelectAllControl(),
            ],
          ),
          const SizedBox(height: DagacsSpace.md),
          _buildCounters(),
        ],
      ),
    );
  }

  Widget _buildSelectAllControl() {
    final state = _selectAllState;
    final enabled = !_submitting;
    return Semantics(
      button: true,
      checked: state == SelectAllState.all,
      mixed: state == SelectAllState.some,
      label: 'Select All',
      child: InkWell(
        onTap: enabled ? _toggleSelectAll : null,
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: DagacsSpace.sm, vertical: DagacsSpace.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  tristate: true,
                  value: state == SelectAllState.all
                      ? true
                      : state == SelectAllState.none
                          ? false
                          : null,
                  onChanged: enabled
                      ? (_) => _toggleSelectAll()
                      : null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: DagacsSpace.xs),
              Text(
                'Select All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? DagacsColors.textPrimary
                      : DagacsColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounters() {
    return Row(
      children: [
        _buildCounterChip('Present', _presentCount, DagacsColors.success),
        const SizedBox(width: DagacsSpace.sm),
        _buildCounterChip('Absent', _absentCount, DagacsColors.error),
        const SizedBox(width: DagacsSpace.sm),
        _buildCounterChip('Unmarked', _unmarkedCount, DagacsColors.warning),
      ],
    );
  }

  Widget _buildCounterChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: DagacsSpace.sm, horizontal: DagacsSpace.md),
        decoration: BoxDecoration(
          color: DagacsColors.surfaceAlt,
          borderRadius: BorderRadius.circular(DagacsRadius.sm),
        ),
        // Rendered as ONE text ("Present 38") rather than a bare label plus a
        // separate count. The per-student status badge owns the exact strings
        // "Present"/"Absent"/"Unmarked", and existing tests match on those exact
        // strings, so the counters must never emit a duplicate bare label.
        // FittedBox keeps the longest label ("Unmarked") from overflowing on
        // narrow phones; it is a no-op at every comfortable width.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DagacsColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: '  $count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }

  /// Sticky action bar. Both this and the AppBar SUBMIT call the same
  /// existing _submit(); there is exactly one submission path.
  Widget _buildStickyFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg, DagacsSpace.md, DagacsSpace.lg, DagacsSpace.md),
      decoration: const BoxDecoration(
        color: DagacsColors.surface,
        border: Border(
          top: BorderSide(color: DagacsColors.border, width: 1),
        ),
        boxShadow: DagacsColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final button = SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              loading: _submitting,
              onPressed: _submit,
              child: const Text('Submit Attendance'),
            ),
          );
          // Narrow phones cannot fit the counters and the action side by side,
          // so the action drops to its own full-width row instead of clipping.
          if (constraints.maxWidth < 380) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCounters(),
                const SizedBox(height: DagacsSpace.md),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _buildCounters()),
              const SizedBox(width: DagacsSpace.lg),
              SizedBox(width: 176, child: button),
            ],
          );
        },
      ),
    );
  }

  /// One student row. The status badge stays the interactive 3-state control
  /// (UNMARKED -> PRESENT -> ABSENT -> UNMARKED) via the existing
  /// _toggleStatus; only the presentation and the secondary line change.
  Widget _buildStudentTile(SessionStudent student) {
    final studentId = student.id;
    final markable = studentId != null;
    final status = markable ? _statusMap[studentId] : null;
    final color = status == 'ABSENT'
        ? DagacsColors.error
        : status == 'PRESENT'
            ? DagacsColors.success
            : DagacsColors.textSecondary;
    final background = status == 'ABSENT'
        ? DagacsColors.errorBg
        : status == 'PRESENT'
            ? DagacsColors.successBg
            : DagacsColors.surfaceAlt;

    final enrollment = (student.enrollmentNumber ?? '').trim();

    return AppCard(
      padding: const EdgeInsets.symmetric(
          vertical: DagacsSpace.md, horizontal: DagacsSpace.md),
      child: Row(
        children: [
          AppIconBadge(
            icon: _statusIcon(status),
            color: color,
            backgroundColor: background,
          ),
          const SizedBox(width: DagacsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Enrollment only. Roll number stays in the model/API and is
                  // simply not shown in this list.
                  'Enrollment: ${enrollment.isEmpty ? '-' : enrollment}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: DagacsSpace.sm),
          Semantics(
            button: true,
            label: 'Change ${student.name ?? 'student'} attendance status',
            child: TextButton(
              onPressed: markable && !_submitting
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
    );
  }
}

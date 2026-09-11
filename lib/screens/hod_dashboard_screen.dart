import 'package:flutter/material.dart';

import '../models/hod_audit_log_entry.dart';
import '../models/hod_dashboard.dart';
import '../models/hod_low_attendance.dart';
import '../models/hod_rollup.dart';
import '../models/hod_section_attendance.dart';
import '../models/hod_student_attendance.dart';
import '../models/hod_subject_attendance.dart';
import '../network/api_exception.dart';
import '../repositories/hod_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';

/// Read-only HOD governance & analytics dashboard.
///
/// Seven tabs. Every number shown is an authoritative backend aggregate —
/// Flutter never recalculates attendance percentages. The optional date range
/// filter is applied screen-wide; only the Dashboard and Rollups endpoints
/// accept it (the other HOD endpoints are all-date by design). Semester
/// rollups are NOT DERIVABLE by the backend, so the Rollups tab offers only
/// Monthly and Quarterly.
class HodDashboardScreen extends StatefulWidget {
  const HodDashboardScreen({super.key, required this.hodRepository});

  final HodRepository hodRepository;

  @override
  State<HodDashboardScreen> createState() => _HodDashboardScreenState();
}

enum _HodTab { dashboard, sections, subjects, students, low, rollups, audit }

class _HodDashboardScreenState extends State<HodDashboardScreen> {
  bool _loading = true;
  Set<_HodTab> _tabErrors = {};

  DateTime? _startDate;
  DateTime? _endDate;

  /// Rejects an invalid start-after-end range client-side (mirrors the M7.3
  /// report screens): no date-bearing request is issued and an inline hint is
  /// shown instead.
  bool get _datesInvalid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isAfter(_endDate!);

  HodDashboard? _dashboard;
  List<HodSectionAttendance> _sections = [];
  List<HodSubjectAttendance> _subjects = [];
  List<HodStudentAttendance> _students = [];
  List<HodLowAttendance> _low = [];
  List<HodAuditLogEntry> _audit = [];

  // Rollups are fetched lazily so a type toggle does not re-run the other tabs.
  String _rollupType = 'monthly';
  bool _rollupsLoading = true;
  String? _rollupsError;
  List<HodRollup> _rollups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_datesInvalid) return;
    setState(() {
      _loading = true;
      _tabErrors = {};
      _rollupsLoading = true;
      _rollupsError = null;
      _rollups = [];
    });
    final errors = <_HodTab>{};

    final dashboard = await _guard(
        () => widget.hodRepository
            .getDashboard(startDate: _startDate, endDate: _endDate),
        errors,
        _HodTab.dashboard);
    final sections = await _guard(
        () => widget.hodRepository
            .getSections(startDate: _startDate, endDate: _endDate),
        errors,
        _HodTab.sections);
    final subjects = await _guard(
        () => widget.hodRepository
            .getSubjects(startDate: _startDate, endDate: _endDate),
        errors,
        _HodTab.subjects);
    final students = await _guard(
        () => widget.hodRepository
            .getStudents(startDate: _startDate, endDate: _endDate),
        errors,
        _HodTab.students);
    final low = await _guard(
        () => widget.hodRepository
            .getLowAttendance(startDate: _startDate, endDate: _endDate),
        errors,
        _HodTab.low);
    final audit = await _guard(
        () => widget.hodRepository
            .getAuditLogs(startDate: _startDate, endDate: _endDate),
        errors,
        _HodTab.audit);

    if (!mounted) return;
    setState(() {
      _dashboard = dashboard;
      _sections = sections ?? [];
      _subjects = subjects ?? [];
      _students = students ?? [];
      _low = low ?? [];
      _audit = audit ?? [];
      _tabErrors = errors;
      _loading = false;
    });

    await _fetchRollups();
  }

  /// Returns the value on success, otherwise records the tab as failed and
  /// returns null. One failed endpoint never takes down the other tabs.
  Future<T?> _guard<T>(Future<T> Function() fetch, Set<_HodTab> errors,
      _HodTab tab) async {
    try {
      return await fetch();
    } on ApiException {
      errors.add(tab);
      return null;
    } catch (_) {
      errors.add(tab);
      return null;
    }
  }

  Future<void> _fetchRollups() async {
    setState(() {
      _rollupsLoading = true;
      _rollupsError = null;
    });
    try {
      final rollups = await widget.hodRepository.getRollups(
        type: _rollupType,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _rollups = rollups;
        _rollupsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _rollupsError = _messageFor(e);
        _rollupsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rollupsError = 'Failed to load attendance rollups.';
        _rollupsLoading = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select start date',
    );
    if (picked == null) return;
    setState(() => _startDate = picked);
    if (_datesInvalid) return;
    await _load();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select end date',
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
    if (_datesInvalid) return;
    await _load();
  }

  Future<void> _clearDates() async {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    await _load();
  }

  String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Session expired. Please sign in again.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HOD Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: Key('tab-dashboard'), text: 'Dashboard'),
              Tab(key: Key('tab-sections'), text: 'Sections'),
              Tab(key: Key('tab-subjects'), text: 'Subjects'),
              Tab(key: Key('tab-students'), text: 'Students'),
              Tab(key: Key('tab-low'), text: 'Low Attendance'),
              Tab(key: Key('tab-rollups'), text: 'Rollups'),
              Tab(key: Key('tab-audit'), text: 'Audit Logs'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildDateBar(),
            Expanded(child: _buildTabBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBar() {
    final hasFilter = _startDate != null || _endDate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('start-date-button'),
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _startDate == null ? 'Start date' : _formatDate(_startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('end-date-button'),
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _endDate == null ? 'End date' : _formatDate(_endDate!),
                  ),
                ),
              ),
              if (hasFilter) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('clear-dates-button'),
                  onPressed: _clearDates,
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.clear),
                ),
              ],
            ],
          ),
          if (_datesInvalid)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Start date must not be after end date.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'The selected range applies to the overview and rollups.',
                style: TextStyle(
                    color: DagacsColors.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Widget _buildTabBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading department analytics...');
    }
    return TabBarView(
      children: [
        _buildDashboardTab(),
        _buildSectionsTab(),
        _buildSubjectsTab(),
        _buildStudentsTab(),
        _buildLowTab(),
        _buildRollupsTab(),
        _buildAuditTab(),
      ],
    );
  }

  Widget _tabError(_HodTab tab, VoidCallback onRetry, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('retry-button'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard tab ───────────────────────────────────────────────

  Widget _buildDashboardTab() {
    if (_tabErrors.contains(_HodTab.dashboard)) {
      return _tabError(_HodTab.dashboard, _load, 'Failed to load dashboard.');
    }
    final d = _dashboard;
    if (d == null) {
      return _tabError(_HodTab.dashboard, _load, 'No dashboard data.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.departmentName,
                    style: Theme.of(context).textTheme.titleLarge),
                Text('Code: ${d.departmentCode}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        _statRow([
          ('Programs', d.programCount),
          ('Batches', d.batchCount),
          ('Sections', d.sectionCount),
          ('Students', d.studentCount),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Overall Attendance',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${d.presentCount} / ${d.totalRecordedCount}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (d.overallPercentage != null)
                  Text(
                    _formatPercentage(d.overallPercentage!),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.blue),
                  )
                else
                  const Text('No attendance records available'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow(List<(String, int)> stats) {
    return Padding(
      padding: const EdgeInsets.only(top: DagacsSpace.sm),
      child: AppResponsiveGrid(
        crossAxisCount: 2,
        gap: DagacsSpace.sm,
        children: [
          for (final (label, value) in stats)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: DagacsSpace.md),
              child: Column(
                children: [
                  Text('$value', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: DagacsSpace.xs),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── List-building tabs ─────────────────────────────────────────

  Widget _buildSectionsTab() =>
      _buildListTab(_HodTab.sections, 'No section data yet.',
          _sections.map(_sectionTile).toList());

  Widget _buildSubjectsTab() =>
      _buildListTab(_HodTab.subjects, 'No subject data yet.',
          _subjects.map(_subjectTile).toList());

  Widget _buildStudentsTab() =>
      _buildListTab(_HodTab.students, 'No student data yet.',
          _students.map(_studentTile).toList());

  Widget _buildLowTab() {
    if (_tabErrors.contains(_HodTab.low)) {
      return _tabError(
          _HodTab.low, _load, 'Failed to load low-attendance students.');
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Students below the fixed 75.0% attendance threshold.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        if (_low.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                SizedBox(height: 16),
                Text('No students below the threshold.'),
              ],
            ),
          )
        else
          for (final s in _low) _lowTile(s),
      ],
    );
  }

  Widget _buildRollupsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<String>(
            key: const Key('rollup-type-selector'),
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ButtonSegment(value: 'quarterly', label: Text('Quarterly')),
            ],
            selected: {_rollupType},
            onSelectionChanged: (values) {
              final type = values.first;
              if (type == _rollupType) return;
              setState(() => _rollupType = type);
              _fetchRollups();
            },
          ),
        ),
        Expanded(child: _buildRollupsBody()),
      ],
    );
  }

  Widget _buildRollupsBody() {
    if (_rollupsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rollupsError != null) {
      return _tabError(_HodTab.rollups, _fetchRollups, _rollupsError!);
    }
    if (_rollups.isEmpty) {
      return const Center(child: Text('No rollup data for this period.'));
    }
    return ListView.builder(
      itemCount: _rollups.length,
      itemBuilder: (context, index) {
        final r = _rollups[index];
        return ListTile(
          leading: const Icon(Icons.date_range),
          title: Text(r.period),
          subtitle: Text('${r.presentCount} / ${r.totalRecordedCount} recorded'),
          trailing: Text(
            r.percentage == null
                ? 'No data'
                : _formatPercentage(r.percentage!),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.blue),
          ),
        );
      },
    );
  }

  Widget _buildAuditTab() {
    if (_tabErrors.contains(_HodTab.audit)) {
      return _tabError(_HodTab.audit, _load, 'Failed to load audit logs.');
    }
    if (_audit.isEmpty) {
      return const Center(child: Text('No audit log entries yet.'));
    }
    return ListView.builder(
      itemCount: _audit.length,
      itemBuilder: (context, index) {
        final e = _audit[index];
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
    );
  }

  Widget _buildListTab(_HodTab tab, String emptyText, List<Widget> tiles) {
    if (_tabErrors.contains(tab)) {
      return _tabError(tab, _load, 'Failed to load data.');
    }
    if (tiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(children: tiles);
  }

  Widget _sectionTile(HodSectionAttendance s) {
    return ListTile(
      leading: const Icon(Icons.meeting_room),
      title: Text('${s.sectionName} (${s.sectionCode})'),
      subtitle: Text('${s.studentCount} students'),
      trailing: Text(
        s.percentage == null
            ? 'No data'
            : _formatPercentage(s.percentage!),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.blue),
      ),
    );
  }

  Widget _subjectTile(HodSubjectAttendance s) {
    return ListTile(
      leading: const Icon(Icons.book),
      title: Text('${s.subjectName} (${s.subjectCode})'),
      subtitle: Text('${s.presentCount} present / ${s.totalRecordedCount} recorded'),
      trailing: Text(
        s.percentage == null
            ? 'No data'
            : _formatPercentage(s.percentage!),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.blue),
      ),
    );
  }

  Widget _lowTile(HodLowAttendance s) {
    return ListTile(
      leading: const Icon(Icons.warning_amber),
      title: Text('${s.studentName} (${s.rollNumber})'),
      subtitle: Text(
          '${s.sectionName} | ${s.presentCount} / ${s.totalRecordedCount} recorded'),
      trailing: Text(
        s.percentage == null
            ? 'No data'
            : _formatPercentage(s.percentage!),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.red),
      ),
    );
  }

  Widget _studentTile(HodStudentAttendance s) {
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text('${s.studentName} (${s.rollNumber})'),
      subtitle: Text(
          '${s.sectionName} | ${s.presentCount} / ${s.totalRecordedCount} recorded'),
      trailing: Text(
        s.percentage == null
            ? 'No data'
            : _formatPercentage(s.percentage!),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.blue),
      ),
    );
  }

  String _formatPercentage(double value) {
    final text = value.toString();
    final trimmed = text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text;
    return '$trimmed%';
  }
}

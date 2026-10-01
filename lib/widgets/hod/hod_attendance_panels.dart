import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_attendance_matrix.dart';
import '../../models/hod_attendance_overview.dart';
import '../../models/hod_low_attendance_report.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../attendance_summary_cards.dart';
import '../dagacs_widgets.dart';
import 'hod_common.dart';
import 'hod_matrix_table.dart';

/// The exact message shown when a report cannot be produced because the
/// academic context is incomplete. Identical to the server's contract message.
const String kHodMatrixContextRequiredMessage =
    'Select Academic Session, Program, Semester and Section to view the '
    'Attendance Matrix.';

/// The message shown when a partial context is too little for a report that
/// needs a concrete student population.
const String kHodStudentContextRequiredMessage =
    'Select Academic Session, Program, Semester and Section to view this '
    'report.';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared states
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// What a report panel has actually loaded, for the export summary strip.
///
/// <b>No API call is involved.</b> A panel already holds the data it rendered, so
/// it publishes the counts it already computed and the export strip shows them.
/// Asking the server again "just for the preview" would be a second request that
/// could return a different moment in time, which is precisely the data drift
/// Phase 4A exists to eliminate.
@immutable
class HodReportSummary {
  const HodReportSummary({this.studentCount, this.subjectCount});

  /// Distinct students in the loaded report, when the report has any.
  final int? studentCount;

  /// Distinct subjects in the loaded report, when the report has any.
  final int? subjectCount;

  /// A summary that says nothing, for a report with no countable population.
  static const HodReportSummary none = HodReportSummary();
}

/// The "no academic context yet" state, shared by every context-bound report.
///
/// It is a first-class state rather than a silent empty table, so a HOD is never
/// shown a department-wide report while believing it is looking at a section.
class HodContextRequiredView extends StatelessWidget {
  const HodContextRequiredView({
    super.key,
    this.message = kHodStudentContextRequiredMessage,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('hod-context-required'),
      child: Padding(
        padding: const EdgeInsets.all(DagacsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined,
                size: 44, color: DagacsColors.textSecondary),
            const SizedBox(height: DagacsSpace.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DagacsTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading / error / empty handling shared by the Phase 3 report panels.
///
/// Kept deliberately small: the panels own their data, this owns only the three
/// states every one of them must render distinctly rather than collapsing them
/// into a blank screen.
class HodReportStates extends StatelessWidget {
  const HodReportStates({
    super.key,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.child,
    this.loadingMessage = 'Loading...',
    this.empty = false,
    this.emptyMessage = 'No data for the current academic context.',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Widget child;
  final String loadingMessage;

  /// True when the request succeeded and genuinely returned nothing.
  final bool empty;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppLoadingState(message: loadingMessage);
    }
    if (errorMessage != null) {
      return HodErrorView(message: errorMessage!, onRetry: onRetry);
    }
    if (empty) {
      return Center(
        key: const Key('hod-report-empty'),
        child: Padding(
          padding: const EdgeInsets.all(DagacsSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 40, color: DagacsColors.textSecondary),
              const SizedBox(height: DagacsSpace.md),
              Text(emptyMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return child;
  }
}

/// A metric that has no data source renders as an explicit unavailable state.
///
/// Never a zero: a fabricated 0% is worse than an honest "no data".
class HodMetricTile extends StatelessWidget {
  const HodMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.valueColor,
    this.unavailable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color? valueColor;

  /// Renders "No data" with a muted colour and an accessible explanation.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return AppStatCard(
      icon: icon,
      value: value,
      label: label,
      subtitle: detail,
      valueColor: valueColor ??
          (unavailable ? DagacsColors.textSecondary : null),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Attendance overview
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// The academic-context attendance overview.
///
/// Every number is an authoritative backend aggregate for the selected context,
/// measured against the conducted classes of that context. A metric the backend
/// has no source for renders as an explicit unavailable state, and a student
/// with no conducted class at all is reported separately instead of being folded
/// into a 0% band.
class HodAttendanceOverviewPanel extends StatefulWidget {
  const HodAttendanceOverviewPanel({
    super.key,
    required this.repository,
    required this.academicContext,
    this.reloadToken = 0,
    this.onReportLoaded,
    this.onReportSummary,
    this.onOpenStudent,
    this.onOpenSubject,
  });

  final HodAttendanceRepository repository;
  final HodAcademicContext academicContext;

  /// Incremented by the parent to force a refetch after a context change.
  final int reloadToken;

  /// Called after this panel has loaded a report successfully.
  ///
  /// Phase 4A: the parent uses it to enable its export control and to snapshot
  /// the exact academic context this data belongs to, so a file can never be
  /// produced for a context the screen is not currently showing.
  final VoidCallback? onReportLoaded;

  /// Called with the counts the panel just loaded, for the export summary strip.
  ///
  /// <b>Phase 4A, purely additive.</b> [onReportLoaded] is unchanged, so every
  /// existing caller keeps compiling and behaving identically; a host that only
  /// cares about the load signal simply never passes this.
  final ValueChanged<HodReportSummary>? onReportSummary;

  final ValueChanged<int>? onOpenStudent;
  final ValueChanged<int>? onOpenSubject;

  @override
  State<HodAttendanceOverviewPanel> createState() =>
      _HodAttendanceOverviewPanelState();
}

class _HodAttendanceOverviewPanelState extends State<HodAttendanceOverviewPanel> {
  static const String _errorCopy = 'Failed to load the attendance overview.';

  bool _loading = true;
  String? _error;
  HodAttendanceOverview? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HodAttendanceOverviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      final overview = await widget.repository.getOverview(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
      widget.onReportLoaded?.call();
      // Phase 4A: the report's own figures, so the export strip previews the
      // exact dataset the file will contain. No second request is made.
      widget.onReportSummary?.call(HodReportSummary(
        studentCount: overview.totalStudents,
        subjectCount: overview.subjects.length,
      ));
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
    final overview = _overview;
    return HodReportStates(
      loading: _loading,
      errorMessage: _error,
      onRetry: _load,
      loadingMessage: 'Loading attendance overview...',
      child: SingleChildScrollView(
        key: const Key('hod-attendance-overview'),
        padding: const EdgeInsets.fromLTRB(
            DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, DagacsSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (overview != null && overview.context.complete)
              _contextBanner(overview),
            if (overview != null) ...[
              _metricGrid(overview),
              const SizedBox(height: DagacsSpace.lg),
              _distributionCard(overview),
              const SizedBox(height: DagacsSpace.lg),
              _subjectCard(overview),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contextBanner(HodAttendanceOverview overview) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DagacsSpace.md),
      child: AppCard(
        padding: const EdgeInsets.all(DagacsSpace.md),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined,
                size: 18, color: DagacsColors.brandPrimary),
            const SizedBox(width: DagacsSpace.sm),
            Expanded(
              child: Text(
                overview.context.label,
                key: const Key('hod-overview-context'),
                style: DagacsTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricGrid(HodAttendanceOverview overview) {
    final classes = overview.classesConducted;
    return AppResponsiveGrid(
      crossAxisCount: 3,
      gap: DagacsSpace.md,
      children: [
        HodMetricTile(
          icon: Icons.people_outline,
          label: 'Total Students',
          value: '${overview.totalStudents}',
        ),
        HodMetricTile(
          icon: Icons.percent,
          label: 'Overall Attendance',
          value: formatHodPercentage(overview.overallPercentage),
          detail: '${overview.overallPresentCount} / '
              '${overview.overallTotalClasses} conducted',
          valueColor: hodPercentageColor(overview.overallPercentage),
          unavailable: !overview.hasConductedClasses,
        ),
        HodMetricTile(
          icon: Icons.trending_down,
          label: 'Below '
              '${overview.thresholdPercentage?.toStringAsFixed(0) ?? '75'}%',
          value: '${overview.belowThresholdCount}',
          valueColor: DagacsColors.warning,
        ),
        HodMetricTile(
          icon: Icons.event_available_outlined,
          label: 'Classes Conducted',
          // A metric with no data source is stated as unavailable, never
          // rendered as a misleading zero.
          value: classes == null ? 'No data' : '$classes',
          unavailable: classes == null,
          detail: classes == null
              ? 'Needs a complete academic context'
              : 'Sessions conducted in range',
        ),
        HodMetricTile(
          icon: Icons.hourglass_empty,
          label: 'No Classes Conducted',
          value: '${overview.noConductedClasses}',
          detail: 'Students with no class held in range',
        ),
        HodMetricTile(
          icon: Icons.groups_outlined,
          label: 'Subjects in Context',
          value: '${overview.subjects.length}',
          detail: overview.subjects.isEmpty
              ? 'No subjects offered in this semester'
              : 'Offered subjects with their faculty',
        ),
      ],
    );
  }

  Widget _distributionCard(HodAttendanceOverview overview) {
    final total = overview.totalStudents == 0
        ? 1
        : overview.totalStudents;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance distribution',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DagacsSpace.xs),
          Text(
            'Students of the selected academic context by overall attendance.',
            style: DagacsTextStyles.caption,
          ),
          const SizedBox(height: DagacsSpace.md),
          for (final band in overview.distribution)
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(band.label, style: DagacsTextStyles.caption),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DagacsRadius.pill),
                      child: LinearProgressIndicator(
                        value: band.studentCount / total,
                        minHeight: 8,
                        backgroundColor: DagacsColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _bandColor(band.band),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DagacsSpace.sm),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${band.studentCount}',
                      textAlign: TextAlign.right,
                      style: DagacsTextStyles.caption
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          if (overview.noConductedClasses > 0) ...[
            const SizedBox(height: DagacsSpace.xs),
            Text(
              '${overview.noConductedClasses} student(s) have no conducted '
              'class in range and are therefore in no band.',
              key: const Key('hod-overview-no-data-note'),
              style: DagacsTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  static Color _bandColor(String band) {
    switch (band) {
      case 'high':
        return DagacsColors.success;
      case 'medium':
        return DagacsColors.brandPrimary;
      case 'low':
        return DagacsColors.error;
      default:
        return DagacsColors.textSecondary;
    }
  }

  Widget _subjectCard(HodAttendanceOverview overview) {
    if (overview.subjects.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Subject attendance',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: DagacsSpace.sm),
            Text('No subjects are offered in the selected semester.'),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject attendance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DagacsSpace.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const Key('hod-overview-subject-table'),
              columns: const [
                DataColumn(label: Text('Subject Code')),
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Faculty')),
                DataColumn(label: Text('Classes'), numeric: true),
                DataColumn(label: Text('Present'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Attendance %'), numeric: true),
              ],
              rows: [
                for (final subject in overview.subjects)
                  DataRow(
                    key: ValueKey('hod-overview-subject-${subject.subjectId}'),
                    onSelectChanged: widget.onOpenSubject == null
                        ? null
                        : (_) => widget.onOpenSubject!(subject.subjectId),
                    cells: [
                      DataCell(Text(subject.subjectCode)),
                      DataCell(Text(subject.subjectName)),
                      DataCell(Text(subject.facultyLabel)),
                      DataCell(Text('${subject.classesConducted}')),
                      DataCell(Text('${subject.presentCount}')),
                      DataCell(Text('${subject.totalClasses}')),
                      DataCell(Text(formatHodPercentage(subject.percentage))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Attendance matrix
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// The HOD attendance cross-tab for a fully-resolved academic context.
///
/// Subject columns are dynamic and come from the selected context only. Paging,
/// sorting and the cell arithmetic are all performed by the backend, so the
/// widget never re-derives an attendance number and a stale page can never be
/// mistaken for the current one.
class HodAttendanceMatrixPanel extends StatefulWidget {
  const HodAttendanceMatrixPanel({
    super.key,
    required this.repository,
    required this.academicContext,
    this.reloadToken = 0,
    this.onReportLoaded,
    this.onReportSummary,
    this.onOpenStudent,
    this.showContextRequired = true,
  });

  final HodAttendanceRepository repository;
  final HodAcademicContext academicContext;
  final int reloadToken;

  /// Called after this panel has loaded a report successfully.
  ///
  /// Phase 4A: the parent uses it to enable its export control and to snapshot
  /// the exact academic context this data belongs to, so a file can never be
  /// produced for a context the screen is not currently showing.
  final VoidCallback? onReportLoaded;

  /// Called with the counts the panel just loaded, for the export summary strip.
  ///
  /// <b>Phase 4A, purely additive.</b> [onReportLoaded] is unchanged, so every
  /// existing caller keeps compiling and behaving identically; a host that only
  /// cares about the load signal simply never passes this.
  final ValueChanged<HodReportSummary>? onReportSummary;

  /// Invoked with the tapped student's id. A row is only tappable when a
  /// callback is supplied, so the affordance never leads nowhere.
  final ValueChanged<int>? onOpenStudent;

  /// When false, the panel renders nothing instead of the
  /// "select the academic context" instruction. Only a host that already
  /// presents the requirement elsewhere should turn it off; the default keeps
  /// the contract visible so a mixed-context matrix can never be mistaken for a
  /// valid one.
  final bool showContextRequired;

  @override
  State<HodAttendanceMatrixPanel> createState() =>
      _HodAttendanceMatrixPanelState();
}

class _HodAttendanceMatrixPanelState extends State<HodAttendanceMatrixPanel> {
  static const String _errorCopy = 'Failed to load the attendance matrix.';

  int _page = 0;
  HodMatrixSort _sort = HodMatrixSort.enrollmentNumber;
  bool _ascending = true;

  bool _loading = true;
  String? _error;
  HodAttendanceMatrix? _matrix;

  bool get _hasContext =>
      widget.academicContext.academicSessionId != null &&
      widget.academicContext.programId != null &&
      widget.academicContext.semesterId != null &&
      widget.academicContext.sectionId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HodAttendanceMatrixPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      // Any context change invalidates the previous page, ordering and sort.
      setState(() {
        _page = 0;
        _sort = HodMatrixSort.enrollmentNumber;
        _ascending = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    if (!_hasContext) {
      setState(() {
        _loading = false;
        _matrix = null;
        _error = null;
      });
      return;
    }
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      final matrix = await widget.repository.getMatrix(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        subjectId: ctx.subjectId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
        page: _page,
        size: HodAttendanceRepository.defaultMatrixPageSize,
        sortBy: _sort.value,
        direction: _ascending ? 'asc' : 'desc',
      );
      if (!mounted) return;
      setState(() {
        _matrix = matrix;
        _loading = false;
      });
      widget.onReportLoaded?.call();
      // Phase 4A: the report's own figures, so the export strip previews the
      // exact dataset the file will contain. No second request is made.
      widget.onReportSummary?.call(HodReportSummary(
        studentCount: matrix.students.length,
        subjectCount: matrix.subjects.length,
      ));
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

  void _goToPage(int page) {
    setState(() => _page = page);
    _load();
  }

  void _onSortChanged(HodMatrixSort sort) {
    setState(() {
      // Tapping the active column flips the direction; a new column starts
      // ascending, which is the academic default.
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
      _page = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContext) {
      if (!widget.showContextRequired) return const SizedBox.shrink();
      return const HodContextRequiredView(
          message: kHodMatrixContextRequiredMessage);
    }
    final matrix = _matrix;
    return HodReportStates(
      loading: _loading,
      errorMessage: _error,
      onRetry: _load,
      loadingMessage: 'Loading attendance matrix...',
      empty: matrix != null && matrix.isEmpty,
      emptyMessage: matrix != null && matrix.hasNoSubjectColumns
          ? 'No subjects are offered in the selected semester, so there are no '
              'subject columns to report.'
          : 'No students are enrolled in the selected academic context.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summary(matrix),
          Expanded(
            child: HodMatrixTable(
              columns: matrix?.subjects ?? const [],
              rows: matrix?.students ?? const [],
              sort: _sort,
              sortAscending: _ascending,
              onSortChanged: _onSortChanged,
              onRowTap: widget.onOpenStudent == null
                  ? null
                  : (row) => widget.onOpenStudent!(row.studentId),
              thresholdPercentage: matrix?.thresholdPercentage,
            ),
          ),
          _pagination(matrix),
        ],
      ),
    );
  }

  Widget _summary(HodAttendanceMatrix? matrix) {
    if (matrix == null) return const SizedBox.shrink();
    final label = matrix.singleSubject && matrix.subjects.isNotEmpty
        ? 'Subject: ${matrix.subjects.first.fullLabel}'
        : 'All subjects in the selected semester';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, DagacsSpace.sm),
      child: Row(
        children: [
          const Icon(Icons.table_chart_outlined,
              size: 18, color: DagacsColors.brandPrimary),
          const SizedBox(width: DagacsSpace.sm),
          Expanded(
            child: Text(
              '$label Â· ${matrix.totalElements} student(s)',
              key: const Key('hod-matrix-summary'),
              style: DagacsTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagination(HodAttendanceMatrix? matrix) {
    if (matrix == null || matrix.totalPages <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DagacsSpace.md, vertical: DagacsSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('hod-matrix-prev-page'),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed:
                matrix.hasPreviousPage && !_loading ? () => _goToPage(_page - 1) : null,
          ),
          Text('Page ${_page + 1} of ${matrix.totalPages}'),
          IconButton(
            key: const Key('hod-matrix-next-page'),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: matrix.hasNextPage && !_loading ? () => _goToPage(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Student attendance
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// The students of the selected academic context with their overall attendance,
/// each tappable through to the subject-wise detail.
///
/// Built on the attendance matrix so a HOD sees the same totals, the same
/// threshold and the same "no conducted class" handling as the cross-tab â€”
/// one source of truth, not a second, looser student aggregate.
class HodStudentAttendancePanel extends StatefulWidget {
  const HodStudentAttendancePanel({
    super.key,
    required this.repository,
    required this.academicContext,
    this.reloadToken = 0,
    this.onReportLoaded,
    this.onReportSummary,
    this.onOpenStudent,
  });

  final HodAttendanceRepository repository;
  final HodAcademicContext academicContext;
  final int reloadToken;

  /// Called after this panel has loaded a report successfully.
  ///
  /// Phase 4A: the parent uses it to enable its export control and to snapshot
  /// the exact academic context this data belongs to, so a file can never be
  /// produced for a context the screen is not currently showing.
  final VoidCallback? onReportLoaded;

  /// Called with the counts the panel just loaded, for the export summary strip.
  ///
  /// <b>Phase 4A, purely additive.</b> [onReportLoaded] is unchanged, so every
  /// existing caller keeps compiling and behaving identically; a host that only
  /// cares about the load signal simply never passes this.
  final ValueChanged<HodReportSummary>? onReportSummary;
  final ValueChanged<int>? onOpenStudent;

  @override
  State<HodStudentAttendancePanel> createState() =>
      _HodStudentAttendancePanelState();
}

class _HodStudentAttendancePanelState extends State<HodStudentAttendancePanel> {
  static const String _errorCopy = 'Failed to load the students.';

  bool _loading = true;
  String? _error;
  HodAttendanceMatrix? _matrix;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HodStudentAttendancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      // Built on the attendance matrix, so this list and the cross-tab can never
      // disagree about a student's total.
      final matrix = await widget.repository.getMatrix(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        subjectId: ctx.subjectId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
        page: 0,
        size: HodAttendanceRepository.defaultMatrixPageSize,
      );
      if (!mounted) return;
      setState(() {
        _matrix = matrix;
        _loading = false;
      });
      widget.onReportLoaded?.call();
      // Phase 4A: the report's own figures, so the export strip previews the
      // exact dataset the file will contain. No second request is made.
      widget.onReportSummary?.call(HodReportSummary(
        studentCount: matrix.students.length,
        subjectCount: matrix.subjects.length,
      ));
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
    final matrix = _matrix;
    return HodReportStates(
      loading: _loading,
      errorMessage: _error,
      onRetry: _load,
      loadingMessage: 'Loading students...',
      empty: matrix != null && matrix.isEmpty,
      emptyMessage:
          'No students are enrolled in the selected academic context.',
      child: ListView.builder(
        key: const Key('hod-student-attendance-list'),
        padding: const EdgeInsets.only(bottom: DagacsSpace.lg),
        itemCount: matrix?.students.length ?? 0,
        itemBuilder: (context, index) {
          final row = matrix!.students[index];
          return ListTile(
            key: Key('hod-student-attendance-row-${row.studentId}'),
            onTap: widget.onOpenStudent == null
                ? null
                : () => widget.onOpenStudent!(row.studentId),
            leading: const Icon(Icons.person),
            title: Text('${row.studentName} (${row.identity})'),
            subtitle: Text(
              '${row.totalPresent} / ${row.totalClasses} conducted'
              '${row.sectionName.isEmpty ? '' : ' Â· Section ${row.sectionName}'}',
            ),
            trailing: Text(
              formatHodPercentage(row.overallPercentage),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AttendanceSummaryCards.bandColor(
                        row.overallPercentage),
                  ),
            ),
          );
        },
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Subject attendance
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// The subjects of the selected academic context with their faculty, classes and
/// attendance, each tappable through to the student-wise detail.
class HodSubjectAttendancePanel extends StatefulWidget {
  const HodSubjectAttendancePanel({
    super.key,
    required this.repository,
    required this.academicContext,
    this.reloadToken = 0,
    this.onReportLoaded,
    this.onReportSummary,
    this.onOpenSubject,
  });

  final HodAttendanceRepository repository;
  final HodAcademicContext academicContext;
  final int reloadToken;

  /// Called after this panel has loaded a report successfully.
  ///
  /// Phase 4A: the parent uses it to enable its export control and to snapshot
  /// the exact academic context this data belongs to, so a file can never be
  /// produced for a context the screen is not currently showing.
  final VoidCallback? onReportLoaded;

  /// Called with the counts the panel just loaded, for the export summary strip.
  ///
  /// <b>Phase 4A, purely additive.</b> [onReportLoaded] is unchanged, so every
  /// existing caller keeps compiling and behaving identically; a host that only
  /// cares about the load signal simply never passes this.
  final ValueChanged<HodReportSummary>? onReportSummary;
  final ValueChanged<int>? onOpenSubject;

  @override
  State<HodSubjectAttendancePanel> createState() =>
      _HodSubjectAttendancePanelState();
}

class _HodSubjectAttendancePanelState extends State<HodSubjectAttendancePanel> {
  static const String _errorCopy = 'Failed to load the subjects.';

  bool _loading = true;
  String? _error;
  HodAttendanceOverview? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HodSubjectAttendancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      final overview = await widget.repository.getOverview(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
      widget.onReportLoaded?.call();
      // Phase 4A: the report's own figures, so the export strip previews the
      // exact dataset the file will contain. No second request is made.
      widget.onReportSummary?.call(HodReportSummary(
        subjectCount: overview.subjects.length,
      ));
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
    final subjects = _overview?.subjects ?? const [];
    return HodReportStates(
      loading: _loading,
      errorMessage: _error,
      onRetry: _load,
      loadingMessage: 'Loading subjects...',
      empty: !_loading && _error == null && subjects.isEmpty,
      emptyMessage:
          'No subjects are offered in the selected academic context.',
      child: ListView.builder(
        key: const Key('hod-subject-attendance-list'),
        padding: const EdgeInsets.only(bottom: DagacsSpace.lg),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          return ListTile(
            key: Key('hod-subject-attendance-row-${subject.subjectId}'),
            onTap: widget.onOpenSubject == null
                ? null
                : () => widget.onOpenSubject!(subject.subjectId),
            leading: const Icon(Icons.book),
            title: Text('${subject.subjectName} (${subject.subjectCode})'),
            subtitle: Text([
              subject.facultyLabel,
              '${subject.classesConducted} class(es) conducted',
              '${subject.presentCount} / ${subject.totalClasses} conducted',
            ].join(' Â· ')),
            trailing: Text(
              formatHodPercentage(subject.percentage),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AttendanceSummaryCards.bandColor(subject.percentage),
                  ),
            ),
          );
        },
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Low attendance
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// The context-scoped low-attendance report with the subjects responsible.
///
/// The threshold is the application's existing fixed rule, echoed from the
/// backend. No "critical" band is offered, because no such threshold is defined
/// anywhere in the application and inventing one would create a second,
/// conflicting interpretation of the same data.
class HodLowAttendancePanel extends StatefulWidget {
  const HodLowAttendancePanel({
    super.key,
    required this.repository,
    required this.academicContext,
    this.reloadToken = 0,
    this.onReportLoaded,
    this.onReportSummary,
    this.onOpenStudent,
  });

  final HodAttendanceRepository repository;
  final HodAcademicContext academicContext;
  final int reloadToken;

  /// Called after this panel has loaded a report successfully.
  ///
  /// Phase 4A: the parent uses it to enable its export control and to snapshot
  /// the exact academic context this data belongs to, so a file can never be
  /// produced for a context the screen is not currently showing.
  final VoidCallback? onReportLoaded;

  /// Called with the counts the panel just loaded, for the export summary strip.
  ///
  /// <b>Phase 4A, purely additive.</b> [onReportLoaded] is unchanged, so every
  /// existing caller keeps compiling and behaving identically; a host that only
  /// cares about the load signal simply never passes this.
  final ValueChanged<HodReportSummary>? onReportSummary;
  final ValueChanged<int>? onOpenStudent;

  @override
  State<HodLowAttendancePanel> createState() => _HodLowAttendancePanelState();
}

class _HodLowAttendancePanelState extends State<HodLowAttendancePanel> {
  static const String _errorCopy = 'Failed to load low-attendance students.';

  bool _loading = true;
  String? _error;
  HodLowAttendanceReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HodLowAttendancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      // The canonical low-attendance report: threshold, population and the
      // subjects responsible for each student.
      final report = await widget.repository.getLowAttendance(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
      widget.onReportLoaded?.call();
      // Phase 4A: the report's own figures, so the export strip previews the
      // exact dataset the file will contain. No second request is made.
      widget.onReportSummary?.call(HodReportSummary(
        studentCount: report.students.length,
      ));
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
    final report = _report;
    return HodReportStates(
      loading: _loading,
      errorMessage: _error,
      onRetry: _load,
      loadingMessage: 'Loading low-attendance students...',
      empty: report != null && report.isEmpty,
      emptyIcon: Icons.check_circle_outline,
      emptyMessage:
          'No students in the selected academic context are below the '
          'attendance threshold.',
      child: ListView.builder(
        key: const Key('hod-low-attendance-report'),
        padding: const EdgeInsets.fromLTRB(
            DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, DagacsSpace.xl),
        itemCount: (report?.students.length ?? 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: Text(
                'Below the fixed '
                '${report?.thresholdPercentage?.toStringAsFixed(1) ?? '75.0'}% '
                'threshold Â· ${report?.belowThresholdCount ?? 0} of '
                '${report?.totalStudents ?? 0} students in context',
                key: const Key('hod-low-attendance-summary'),
                style: DagacsTextStyles.caption,
              ),
            );
          }
          return _studentCard(report!.students[index - 1]);
        },
      ),
    );
  }

  Widget _studentCard(HodLowAttendanceStudent student) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
      child: AppCard(
        key: Key('hod-low-attendance-student-${student.studentId}'),
        onTap: widget.onOpenStudent == null
            ? null
            : () => widget.onOpenStudent!(student.studentId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber,
                    size: 20, color: DagacsColors.warning),
                const SizedBox(width: DagacsSpace.sm),
                Expanded(
                  child: Text(
                    '${student.studentName} (${student.identity})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DagacsTextStyles.cardTitle,
                  ),
                ),
                Text(
                  formatHodPercentage(student.percentage),
                  style: DagacsTextStyles.cardTitle
                      .copyWith(color: hodPercentageColor(student.percentage)),
                ),
              ],
            ),
            const SizedBox(height: DagacsSpace.xs),
            Text(
              [
                if (student.academicSessionName != null) student.academicSessionName!,
                if (student.programName != null) student.programName!,
                if (student.semesterName != null) student.semesterName!,
                if (student.sectionName.isNotEmpty) student.sectionName,
                '${student.presentCount} / ${student.totalClasses} conducted',
              ].join(' Â· '),
              style: DagacsTextStyles.caption,
            ),
            if (student.hasBreakdown) ...[
              const SizedBox(height: DagacsSpace.sm),
              Text(
                'Subjects below threshold (${student.subjectsBelowThreshold})',
                style: DagacsTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: DagacsSpace.xs),
              Wrap(
                spacing: DagacsSpace.sm,
                runSpacing: DagacsSpace.xs,
                children: [
                  for (final subject in student.belowThresholdSubjects)
                    _culpritChip(subject),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _culpritChip(HodLowAttendanceSubject subject) {
    final percentage = subject.percentage;
    return Tooltip(
      message: '${subject.subjectName}: ${subject.present} of ${subject.total} '
          'conducted classes attended',
      child: Container(
        key: Key('hod-low-attendance-subject-${subject.subjectId}'),
        padding: const EdgeInsets.symmetric(horizontal: DagacsSpace.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AttendanceSummaryCards.bandColor(percentage).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DagacsRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subject.label,
              style: DagacsTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AttendanceSummaryCards.bandColor(percentage),
              ),
            ),
            const SizedBox(width: DagacsSpace.xs),
            Text(
              percentage == null
                  ? 'N/A'
                  : '${percentage.toStringAsFixed(1)}%',
              style: DagacsTextStyles.caption.copyWith(
                color: AttendanceSummaryCards.bandColor(percentage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

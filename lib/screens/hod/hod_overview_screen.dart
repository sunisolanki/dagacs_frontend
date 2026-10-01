import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_dashboard.dart';
import '../../models/hod_subject_attendance.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../repositories/hod_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../widgets/dagacs_widgets.dart';
import '../../widgets/hod/hod_attendance_panels.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Department overview, replacing the previous HOD dashboard's "Dashboard" tab
/// with a full route.
///
/// Every number rendered here is an authoritative backend aggregate that the
/// HOD module already consumed; nothing is recalculated client-side. Metrics
/// with no verified data source are rendered as explicitly unavailable rather
/// than as a misleading zero.
///
/// When [attendanceRepository] is supplied and a complete academic context is
/// selected, the screen additionally leads with the Phase 3 context overview
/// (total students, overall attendance, below-threshold count, classes
/// conducted, the attendance distribution and the subject table). The
/// department-wide cards stay below it, labelled as such, so nothing that
/// worked before is hidden or reinterpreted.
class HodOverviewScreen extends StatefulWidget {
  const HodOverviewScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
    this.hierarchyLoader,
    this.attendanceRepository,
    this.onOpenStudent,
    this.onOpenSubject,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;

  /// Supplies the real academic hierarchy to the context bar.
  final HodHierarchyLoader? hierarchyLoader;

  /// Enables the academic-context attendance overview. Optional so a host
  /// without it keeps the previous department-wide overview exactly.
  final HodAttendanceRepository? attendanceRepository;

  final ValueChanged<int>? onOpenStudent;
  final ValueChanged<int>? onOpenSubject;

  @override
  State<HodOverviewScreen> createState() => _HodOverviewScreenState();
}

class _HodOverviewScreenState extends State<HodOverviewScreen> {
  static const String _errorCopy = 'Failed to load dashboard.';

  bool _loading = true;
  String? _error;

  HodDashboard? _dashboard;
  List<HodSubjectAttendance> _subjects = [];
  int _belowThresholdCount = 0;

  /// Bumped on every academic-context change so the context panel refetches.
  int _contextReloadToken = 0;

  @override
  void initState() {
    super.initState();
    // Kick off the one-time hierarchy root load; the context bar reflects its
    // status. Failure is surfaced by the bar, never as an empty dashboard.
    widget.hierarchyLoader?.ensureRoot();
    _load();
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await widget.hodRepository.getDashboard(
        startDate: widget.academicContext.startDate,
        endDate: widget.academicContext.endDate,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
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

    await _loadSecondary();
  }

  /// Secondary panels fail independently so a missing sub-report never blanks
  /// the department overview.
  Future<void> _loadSecondary() async {
    try {
      final subjects = await widget.hodRepository.getSubjects(
        startDate: widget.academicContext.startDate,
        endDate: widget.academicContext.endDate,
      );
      final low = await widget.hodRepository.getLowAttendance(
        startDate: widget.academicContext.startDate,
        endDate: widget.academicContext.endDate,
      );
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _belowThresholdCount = low.length;
      });
    } on ApiException {
      // Keep the overview usable; the panels render their unavailable state.
    } catch (_) {
      // Same rationale: a secondary failure must not break the overview.
    }
  }

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'HOD Overview',
      subtitle: 'Department attendance monitoring at a glance.',
      icon: Icons.dashboard_outlined,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _onContextChanged,
      body: _buildBody(),
    );
  }

  void _onContextChanged() {
    setState(() => _contextReloadToken++);
    _load();
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading department analytics...');
    }
    if (_error != null) {
      return HodErrorView(message: _error!, onRetry: _load);
    }
    final d = _dashboard;
    if (d == null) {
      return HodErrorView(message: 'No dashboard data.', onRetry: _load);
    }

    return ListView(
      key: const Key('hod-overview-list'),
      padding: const EdgeInsets.fromLTRB(
        DagacsSpace.md,
        0,
        DagacsSpace.md,
        DagacsSpace.xl,
      ),
      children: [
        if (_showsContextOverview) ...[
          _sectionTitle('Selected academic context'),
          const SizedBox(height: DagacsSpace.sm),
          // Fixed height: the panel owns its own scrolling, and a nested
          // ListView inside a ListView would be unbounded.
          SizedBox(
            height: 520,
            child: HodAttendanceOverviewPanel(
              repository: widget.attendanceRepository!,
              academicContext: widget.academicContext,
              reloadToken: _contextReloadToken,
              onOpenStudent: widget.onOpenStudent,
              onOpenSubject: widget.onOpenSubject,
            ),
          ),
          const SizedBox(height: DagacsSpace.xl),
        ],
        _departmentCard(d),
        const SizedBox(height: DagacsSpace.lg),
        _sectionTitle('Key indicators'),
        const SizedBox(height: DagacsSpace.sm),
        _kpiGrid(d),
        const SizedBox(height: DagacsSpace.lg),
        _sectionTitle(_showsContextOverview
            ? 'Department-wide overview'
            : 'Academic overview'),
        const SizedBox(height: DagacsSpace.sm),
        const _AcademicOverviewPending(),
        const SizedBox(height: DagacsSpace.lg),
        _sectionTitle(_showsContextOverview
            ? 'Department-wide attendance'
            : 'Attendance overview'),
        const SizedBox(height: DagacsSpace.sm),
        _overallCard(d),
        const SizedBox(height: DagacsSpace.lg),
        _subjectsPanel(),
      ],
    );
  }

  /// True only when the Phase 3 repository is wired and the HOD has selected
  /// every mandatory level. A partial context keeps the previous behaviour
  /// rather than pretending it can produce a context report.
  bool get _showsContextOverview =>
      widget.attendanceRepository != null &&
      widget.academicContext.academicSessionId != null &&
      widget.academicContext.programId != null &&
      widget.academicContext.semesterId != null &&
      widget.academicContext.sectionId != null;

  Widget _departmentCard(HodDashboard d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.departmentName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('Code: ${d.departmentCode}',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );

  Widget _kpiGrid(HodDashboard d) {
    return AppResponsiveGrid(
      crossAxisCount: 3,
      gap: DagacsSpace.md,
      children: [
        AppStatCard(
          icon: Icons.account_tree_outlined,
          value: '${d.programCount}',
          label: 'Programs',
        ),
        AppStatCard(
          icon: Icons.groups_outlined,
          value: '${d.batchCount}',
          label: 'Batches',
        ),
        AppStatCard(
          icon: Icons.meeting_room_outlined,
          value: '${d.sectionCount}',
          label: 'Sections',
        ),
        AppStatCard(
          icon: Icons.people_outline,
          value: '${d.studentCount}',
          label: 'Students',
        ),
        AppStatCard(
          icon: Icons.trending_down,
          value: '$_belowThresholdCount',
          label: 'Below 75%',
          iconColor: DagacsColors.warning,
          iconBackgroundColor: DagacsColors.warningBg,
        ),
        AppStatCard(
          icon: Icons.percent,
          value: d.overallPercentage == null
              ? 'No data'
              : formatHodPercentage(d.overallPercentage),
          label: 'Overall Attendance',
          subtitle: '${d.presentCount} / ${d.totalRecordedCount} recorded',
          valueColor:
              hodPercentageColor(d.overallPercentage),
        ),
        const HodUnavailableCard(
          icon: Icons.event_available_outlined,
          label: 'Classes Conducted',
          detail: 'No data source yet',
        ),
        const HodUnavailableCard(
          icon: Icons.today_outlined,
          label: "Today's Classes",
          detail: 'No data source yet',
        ),
      ],
    );
  }

  Widget _overallCard(HodDashboard d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: DagacsColors.brandPrimary),
              const SizedBox(width: DagacsSpace.sm),
              Text('Overall attendance',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: DagacsSpace.md),
          Text('${d.presentCount} / ${d.totalRecordedCount}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: DagacsSpace.xs),
          if (d.overallPercentage != null)
            Text(
              formatHodPercentage(d.overallPercentage),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: hodPercentageColor(d.overallPercentage),
                  ),
            )
          else
            const Text('No attendance records available'),
          const SizedBox(height: DagacsSpace.md),
          const HodScopeNotice(),
        ],
      ),
    );
  }

  Widget _subjectsPanel() {
    if (_subjects.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject-wise attendance',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: DagacsSpace.sm),
            const Text('No subject data yet.'),
            const SizedBox(height: DagacsSpace.md),
            const HodScopeNotice(),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject-wise attendance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DagacsSpace.md),
          for (final s in _subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: Row(
                children: [
                  const Icon(Icons.book, size: 18, color: DagacsColors.textSecondary),
                  const SizedBox(width: DagacsSpace.sm),
                  Expanded(
                    child: Text('${s.subjectName} (${s.subjectCode})',
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    '${s.presentCount}/${s.totalRecordedCount}',
                    style: DagacsTextStyles.caption,
                  ),
                  const SizedBox(width: DagacsSpace.md),
                  SizedBox(
                    width: 72,
                    child: Text(
                      formatHodPercentage(s.percentage),
                      textAlign: TextAlign.right,
                      style: DagacsTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hodPercentageColor(s.percentage),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: DagacsSpace.sm),
          const HodScopeNotice(),
        ],
      ),
    );
  }
}

/// The Program x Semester overview needs a hierarchy-scoped aggregation that
/// does not exist yet. It is stated as unavailable rather than filled in with
/// invented or department-wide-as-semester numbers.
class _AcademicOverviewPending extends StatelessWidget {
  const _AcademicOverviewPending();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Program and semester breakdown',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DagacsSpace.sm),
          Row(
            children: [
              const Icon(Icons.hourglass_empty,
                  size: 18, color: DagacsColors.textSecondary),
              const SizedBox(width: DagacsSpace.sm),
              const Expanded(
                child: Text(
                  'Requires academic-context filtering, which will be enabled '
                  'in Phase 2.',
                  key: Key('hod-academic-overview-pending'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

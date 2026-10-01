import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_hierarchy.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../dagacs_widgets.dart';

/// The cascading academic-context filter: Academic Session -> Program ->
/// Semester -> Section -> Subject.
///
/// Options come only from the verified, department-scoped hierarchy API. Each
/// level enables itself only once it actually holds values, so a level that
/// has not been reached yet is visibly unavailable instead of silently empty.
/// Loading, empty, unauthorized and error states are distinguished rather than
/// collapsed into "no data".
class HodContextBar extends StatelessWidget {
  const HodContextBar({
    super.key,
    required this.context,
    this.loader,
    this.onLevelChanged,
  });

  final HodAcademicContext context;

  /// Optional loader. When supplied the bar reflects its per-level status and
  /// asks it to fetch the dependent level after a parent changes.
  final HodHierarchyLoader? loader;

  /// Invoked after a level is selected so the owning screen can refetch.
  final ValueChanged<HodContextLevel>? onLevelChanged;

  static const Map<HodContextLevel, String> _labels = {
    HodContextLevel.academicSession: 'Academic Session',
    HodContextLevel.program: 'Program',
    HodContextLevel.semester: 'Semester',
    HodContextLevel.section: 'Section',
    HodContextLevel.subject: 'Subject',
  };

  Future<void> _handleChanged(HodContextLevel level, int? value) async {
    final options = context.optionsFor(level);
    final match = options.where((option) => option.id == value);
    context.select(level, value, name: match.isEmpty ? null : match.first.label);
    onLevelChanged?.call(level);

    final loader = this.loader;
    if (loader == null || value == null) return;

    // Only the dependent level is refetched, never the whole hierarchy.
    switch (level) {
      case HodContextLevel.academicSession:
        // Selecting a session resets the program (a session fixes its own
        // program), so the semesters and sections of the new session are
        // fetched unconditionally.
        await loader.loadSemesters(academicSessionId: value);
        await loader.loadSections(academicSessionId: value);
      case HodContextLevel.program:
        // A session already determines the program, so the program level
        // narrows nothing further and needs no fetch.
        break;
      case HodContextLevel.semester:
        if (context.academicSessionId != null) {
          await loader.loadSections(
            academicSessionId: context.academicSessionId!,
            programId: context.programId,
            semesterId: value,
          );
        }
      case HodContextLevel.section:
        if (context.semesterId != null) {
          await loader.loadSubjects(
            semesterId: context.semesterId!,
            sectionId: value,
          );
        }
      case HodContextLevel.subject:
        break;
    }
  }

  @override
  Widget build(BuildContext buildContext) {
    // The bar is self-sufficient: it rebuilds on a context selection or a
    // hierarchy status change without depending on an ancestor to listen.
    final loader = this.loader;
    return ListenableBuilder(
      listenable:
          Listenable.merge([context, if (loader != null) loader]),
      builder: (context, _) => _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    return Card(
      key: const Key('hod-context-bar'),
      margin: const EdgeInsets.fromLTRB(
        DagacsSpace.md,
        0,
        DagacsSpace.md,
        DagacsSpace.md,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DagacsSpace.md,
          DagacsSpace.md,
          DagacsSpace.md,
          DagacsSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined,
                    size: 18, color: DagacsColors.brandPrimary),
                const SizedBox(width: DagacsSpace.sm),
                Text('Academic context', style: DagacsTextStyles.cardTitle),
              ],
            ),
            const SizedBox(height: DagacsSpace.sm),
            _statusLine(),
            const SizedBox(height: DagacsSpace.md),
            LayoutBuilder(
              builder: (context, constraints) {
                // 5 controls in a row only fit on a wide viewport; below that
                // they wrap so nothing overflows horizontally.
                final columns = constraints.maxWidth >= 900
                    ? 5
                    : constraints.maxWidth >= 600
                        ? 3
                        : 1;
                return Wrap(
                  spacing: DagacsSpace.md,
                  runSpacing: 0,
                  children: [
                    for (final level in HodAcademicContext.levels)
                      SizedBox(
                        width: columns == 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth -
                                    DagacsSpace.md * (columns - 1)) /
                                columns,
                        child: _buildDropdown(level),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusLine() {
    final loader = this.loader;

    if (loader == null) {
      return Text(
        'Academic context filtering is not available.',
        key: const Key('hod-context-pending-notice'),
        style: DagacsTextStyles.caption,
      );
    }

    switch (loader.rootStatus) {
      case HodHierarchyStatus.idle:
      case HodHierarchyStatus.loading:
        return const _LoaderStatus(
            key: Key('hod-context-loading'),
            icon: Icons.hourglass_top,
            message: hodHierarchyLoadingMessage);
      case HodHierarchyStatus.unauthorized:
        return const _LoaderStatus(
            key: Key('hod-context-unauthorized'),
            icon: Icons.lock_outline,
            message: hodHierarchyUnauthorizedMessage);
      case HodHierarchyStatus.error:
        return _LoaderStatus(
            key: const Key('hod-context-error'),
            icon: Icons.error_outline,
            message: loader.rootError ?? hodHierarchyErrorMessage,
            isError: true);
      case HodHierarchyStatus.empty:
        return const _LoaderStatus(
            key: Key('hod-context-empty'),
            icon: Icons.inbox_outlined,
            message: hodHierarchyEmptyMessage);
      case HodHierarchyStatus.ready:
        final semesterStatus = loader.statusFor(HodContextLevel.semester);
        if (semesterStatus == HodHierarchyStatus.loading) {
          return const _LoaderStatus(
              key: Key('hod-context-level-loading'),
              icon: Icons.hourglass_top,
              message: hodHierarchyLoadingMessage);
        }
        if (semesterStatus == HodHierarchyStatus.unauthorized) {
          return const _LoaderStatus(
              key: Key('hod-context-level-unauthorized'),
              icon: Icons.lock_outline,
              message: hodHierarchyUnauthorizedMessage);
        }
        if (semesterStatus == HodHierarchyStatus.error) {
          return _LoaderStatus(
              key: const Key('hod-context-level-error'),
              icon: Icons.error_outline,
              message: loader.errorFor(HodContextLevel.semester) ??
                  hodHierarchyErrorMessage,
              isError: true);
        }
        if (semesterStatus == HodHierarchyStatus.empty) {
          return const _LoaderStatus(
              key: Key('hod-context-level-empty'),
              icon: Icons.filter_alt_off_outlined,
              message: 'No semesters in the selected academic session.');
        }
        return const SizedBox.shrink();
    }
  }

  /// Options offered for a level.
  ///
  /// Program is narrowed to the selected session's own program, so an invalid
  /// program/session pairing cannot be constructed in the UI. Every other level
  /// is published by the loader only for the current parent.
  List<HodContextOption> _visibleOptions(HodContextLevel level) {
    final all = context.optionsFor(level);
    if (level != HodContextLevel.program) return all;
    final sessionProgramId =
        loader?.programIdForSession(context.academicSessionId);
    if (sessionProgramId == null) return all;
    return all.where((option) => option.id == sessionProgramId).toList();
  }

  Widget _buildDropdown(HodContextLevel level) {
    final options = _visibleOptions(level);
    final selectedId = context.idFor(level);
    // A level is usable only once it genuinely holds values.
    final enabled = context.hierarchyAvailable && options.isNotEmpty;

    return AppFormDropdown<int>(
      key: Key('hod-context-dropdown-${level.name}'),
      label: _labels[level]!,
      value: selectedId,
      enabled: enabled,
      items: [
        for (final option in options)
          DropdownMenuItem<int>(
            value: option.id,
            child: Text(
              option.code == null || option.code!.isEmpty
                  ? option.label
                  : '${option.label} (${option.code})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => _handleChanged(level, value),
    );
  }
}

class _LoaderStatus extends StatelessWidget {
  const _LoaderStatus({
    super.key,
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isError ? DagacsColors.error : DagacsColors.textSecondary,
        ),
        const SizedBox(width: DagacsSpace.xs),
        Expanded(
          child: Text(
            message,
            style: DagacsTextStyles.caption.copyWith(
              color: isError ? DagacsColors.error : null,
            ),
          ),
        ),
      ],
    );
  }
}

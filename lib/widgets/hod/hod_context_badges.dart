import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/theme/dagacs_theme.dart';

/// Persistent, always-visible display of the current academic context.
///
/// Renders the selected levels as a compact parent-to-child trail so the HOD
/// never has to guess which academic context a page belongs to. When nothing
/// is selected yet it states that explicitly rather than staying blank.
class HodContextBadges extends StatelessWidget {
  const HodContextBadges({super.key, required this.context});

  final HodAcademicContext context;

  @override
  Widget build(BuildContext buildContext) {
    final chips = context.selectedChips;

    if (chips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          DagacsSpace.lg,
          0,
          DagacsSpace.lg,
          DagacsSpace.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.label_outline,
                size: 16, color: DagacsColors.textSecondary),
            const SizedBox(width: DagacsSpace.xs),
            Expanded(
              child: Text(
                'No academic context selected',
                key: const Key('hod-context-empty'),
                style: DagacsTextStyles.caption,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        0,
        DagacsSpace.lg,
        DagacsSpace.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          key: const Key('hod-context-badges'),
          children: [
            const Icon(Icons.label_outline,
                size: 16, color: DagacsColors.brandPrimary),
            const SizedBox(width: DagacsSpace.xs),
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DagacsSpace.xs),
                  child: Icon(Icons.chevron_right,
                      size: 16, color: DagacsColors.textSecondary),
                ),
              Text(
                chips[i].value,
                style: DagacsTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DagacsColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Drill-down breadcrumb. Phase 1 has no hierarchy source, so it renders only
/// the levels that are actually selected — it never invents a trail.
class HodBreadcrumb extends StatelessWidget {
  const HodBreadcrumb({super.key, required this.context});

  final HodAcademicContext context;

  @override
  Widget build(BuildContext buildContext) {
    final chips = context.selectedChips;
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        0,
        DagacsSpace.lg,
        DagacsSpace.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          key: const Key('hod-breadcrumb'),
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DagacsSpace.xs),
                  child: Text('›', style: TextStyle(color: DagacsColors.textSecondary)),
                ),
              Text(chips[i].value, style: DagacsTextStyles.caption),
            ],
          ],
        ),
      ),
    );
  }
}

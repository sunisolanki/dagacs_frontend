import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../widgets/dagacs_widgets.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Department structure: Program -> Academic Session -> Semester ->
/// Batch/Section -> Subject.
///
/// The hierarchy is intentionally not pre-rendered. No HOD-scoped read
/// endpoint for the academic hierarchy exists yet (every master-data read is
/// ADMIN-only), so this route states that plainly instead of showing invented
/// academic values.
class HodStructureScreen extends StatelessWidget {
  const HodStructureScreen({
    super.key,
    required this.session,
    required this.academicContext,
  });

  final SessionController session;
  final HodAcademicContext academicContext;

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: session,
      academicContext: academicContext,
      title: 'Structure',
      subtitle: 'Programs, semesters, sections and subjects.',
      icon: Icons.account_tree_outlined,
      body: ListView(
        key: const Key('hod-structure-list'),
        padding: const EdgeInsets.all(DagacsSpace.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Department structure',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: DagacsSpace.md),
                for (final level in const [
                  'Program',
                  'Academic Session',
                  'Semester',
                  'Batch / Section',
                  'Subject',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.subdirectory_arrow_right,
                            size: 18, color: DagacsColors.textSecondary),
                        const SizedBox(width: DagacsSpace.sm),
                        // Phase 5.8: inflexible Row child; clipped the moment
                        // the OS font was enlarged on a narrow screen.
                        Expanded(
                          child: Text(level, style: DagacsTextStyles.caption),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DagacsSpace.lg),
          AppCard(
            key: const Key('hod-structure-pending'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hourglass_empty,
                        color: DagacsColors.textSecondary),
                    const SizedBox(width: DagacsSpace.sm),
                    Expanded(
                      child: Text(
                        'Academic context filtering will be enabled in '
                        'Phase 2, including this structure view.',
                        key: const Key('hod-structure-pending-message'),
                      ),
                    ),
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

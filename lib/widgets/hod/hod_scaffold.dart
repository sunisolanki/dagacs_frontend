import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../app_shell.dart';
import '../dagacs_widgets.dart';
import 'hod_context_badges.dart';
import 'hod_context_bar.dart';
import 'hod_date_filter_bar.dart';

/// Shared layout for every HOD route.
///
/// Composition only — it introduces no new visual language. It reuses the
/// existing [AppShell] (sidebar / drawer / branding / user area), the existing
/// [AppPageHeader], and the existing spacing and card tokens, then layers the
/// shared academic-context shell on top:
///
///   page header -> context bar -> persistent context trail -> breadcrumb
///   -> date filter -> page body
///
/// The date filter lives here so the selection persists across HOD routes
/// through the shared [HodAcademicContext].
class HodScaffold extends StatelessWidget {
  const HodScaffold({
    super.key,
    required this.session,
    required this.academicContext,
    required this.title,
    required this.body,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onRangeChanged,
    this.hierarchyLoader,
    this.onContextChanged,
    this.controlsEnabled = true,
  });

  final SessionController session;
  final HodAcademicContext academicContext;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  /// Reload hook fired after a valid date change. Omitted on routes that do not
  /// present a date-filtered panel.
  final VoidCallback? onRangeChanged;

  /// Supplies the real academic hierarchy and its load status to the context bar.
  final HodHierarchyLoader? hierarchyLoader;

  /// Fired after any academic-context level changes, so the page can refetch.
  final VoidCallback? onContextChanged;

  /// Whether the context bar and the date filter accept input.
  ///
  /// <b>Phase 4A.</b> A page that is producing an export file sets this to false
  /// for the duration of the generation. Without it a HOD could switch section
  /// while a request is in flight, and the file would be produced for the old
  /// section while the screen already showed the new one. The lock is what turns
  /// that race from "possible" into "not expressible".
  ///
  /// Defaults to true, so every existing caller keeps its exact behaviour.
  final bool controlsEnabled;

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      session: session,
      body: Column(
        children: [
          Flexible(
            // The context is a ChangeNotifier, so the whole context shell
            // rebuilds whenever a selection or the date range changes. Without
            // this listener the date filter hint and the context trail would
            // keep showing a stale selection.
            child: ListenableBuilder(
              listenable: Listenable.merge(
                  [academicContext, if (hierarchyLoader != null) hierarchyLoader!]),
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: DagacsSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppConstrainedMax(
                      maxWidth: 1120,
                      child: AppPageHeader(
                        icon: icon,
                        title: title,
                        subtitle: subtitle,
                        trailing: trailing,
                      ),
                    ),
                    AppConstrainedMax(
                      maxWidth: 1120,
                      child: HodContextBar(
                        context: academicContext,
                        loader: hierarchyLoader,
                        enabled: controlsEnabled,
                        onLevelChanged: (_) => onContextChanged?.call(),
                      ),
                    ),
                    AppConstrainedMax(
                      maxWidth: 1120,
                      child: HodContextBadges(context: academicContext),
                    ),
                    AppConstrainedMax(
                      maxWidth: 1120,
                      child: HodBreadcrumb(context: academicContext),
                    ),
                    if (onRangeChanged != null)
                      AppConstrainedMax(
                        maxWidth: 1120,
                        child: HodDateFilterBar(
                          context: academicContext,
                          enabled: controlsEnabled,
                          onRangeChanged: onRangeChanged!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

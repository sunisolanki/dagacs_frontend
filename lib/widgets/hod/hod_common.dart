import 'package:flutter/material.dart';

import '../../core/theme/dagacs_theme.dart';
import '../attendance_summary_cards.dart';
import '../dagacs_widgets.dart';

/// Formats a percentage consistently across every HOD screen using two
/// decimal places. A null value renders an explicit "No data" rather than a
/// misleading 0%.
String formatHodPercentage(double? value) =>
    value == null ? 'No data' : '${value.toStringAsFixed(2)}%';

/// Color for an attendance percentage band. Reuses the exact same thresholds
/// as the existing student attendance summary cards so the HOD module never
/// invents a second interpretation of the bands.
Color hodPercentageColor(double? value) =>
    AttendanceSummaryCards.bandColor(value);

/// Inline error state for a single HOD data panel, with a retry affordance.
///
/// Preserves the `retry-button` key used by the previous HOD dashboard so the
/// migrated behavioural tests keep asserting the same interaction.
class HodErrorView extends StatelessWidget {
  const HodErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
}

/// A terminal, non-retryable state: the request was refused because the target
/// is outside the selected academic context.
///
/// Deliberately offers no retry button. Retrying can never turn a student or
/// subject from another context into part of this one, so a retry would invite
/// the reader to keep pressing a button that cannot succeed.
class HodScopeViolationView extends StatelessWidget {
  const HodScopeViolationView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Neutral empty state for a HOD list panel.
class HodEmptyView extends StatelessWidget {
  const HodEmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

/// A capability that is not yet backed by a data source.
///
/// Phase 1 ships the HOD information architecture before the hierarchy and
/// analytics endpoints of a later phase. Wherever a metric or grouping has no
/// verified source yet, this states that explicitly instead of showing a
/// fabricated or misleading zero.
class HodUnavailableCard extends StatelessWidget {
  const HodUnavailableCard({
    super.key,
    required this.icon,
    required this.label,
    this.detail = 'Pending a later phase',
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(DagacsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: icon,
            color: DagacsColors.textSecondary,
            backgroundColor: DagacsColors.surfaceAlt,
            size: 44,
          ),
          const SizedBox(height: DagacsSpace.md),
          Text(
            '--',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: DagacsColors.textSecondary,
            ),
          ),
          const SizedBox(height: DagacsSpace.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DagacsTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: DagacsColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Non-blocking notice explaining that a panel is currently showing
/// department-wide data because academic-context scoping is not yet available.
///
/// It informs the reader without hiding or disabling the data itself.
class HodScopeNotice extends StatelessWidget {
  const HodScopeNotice({super.key, this.message});

  static const String defaultMessage =
      'Department-wide view. Academic context filtering will be enabled in '
      'Phase 2.';

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('hod-scope-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DagacsSpace.md,
        vertical: DagacsSpace.sm,
      ),
      decoration: BoxDecoration(
        color: DagacsColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DagacsRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: DagacsColors.textSecondary),
          const SizedBox(width: DagacsSpace.sm),
          Expanded(
            child: Text(
              message ?? defaultMessage,
              style: DagacsTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared loading / error / empty handling for a HOD list panel.
///
/// Centralises the three states so each migrated screen only supplies its own
/// error copy, empty copy and row builder. The scope notice is optional and is
/// purely informational — it never suppresses data.
class HodListPanel extends StatelessWidget {
  const HodListPanel({
    super.key,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyMessage,
    this.loadingMessage = 'Loading...',
    this.showScopeNotice = true,
  });

  final bool loading;

  /// Fixed, user-facing error copy for this panel. Null when it loaded
  /// successfully.
  final String? errorMessage;

  final VoidCallback onRetry;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String? emptyMessage;
  final String loadingMessage;
  final bool showScopeNotice;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppLoadingState(message: loadingMessage);
    }
    if (errorMessage != null) {
      return HodErrorView(message: errorMessage!, onRetry: onRetry);
    }
    if (itemCount == 0 && emptyMessage != null) {
      return HodEmptyView(message: emptyMessage!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showScopeNotice)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              DagacsSpace.md,
              0,
              DagacsSpace.md,
              DagacsSpace.sm,
            ),
            child: HodScopeNotice(),
          ),
        Expanded(
          child: ListView.builder(
            key: const Key('hod-list'),
            padding: const EdgeInsets.only(bottom: DagacsSpace.lg),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}


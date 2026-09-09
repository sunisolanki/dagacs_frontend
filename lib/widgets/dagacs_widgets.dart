import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';

/// Shared visual components for the DAGACS premium UI.
///
/// Every component is resilient to running under a plain [Material] theme (no
/// app theme installed) by falling back to the built-in light tokens, which
/// keeps the target screens usable inside widget tests that do not set a theme.

String _initialsOf(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Circular initials avatar used for people and generic entities.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? DagacsColors.brandSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: foregroundColor ?? DagacsColors.brandDark,
        ),
      ),
    );
  }
}

/// Prominent rounded icon tile shown as the leading element of feature cards.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = DagacsColors.brandPrimary,
    this.backgroundColor = DagacsColors.brandSoft,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DagacsRadius.lg),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Pill that communicates the current user role.
class AppRoleChip extends StatelessWidget {
  const AppRoleChip({super.key, required this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final label = (role ?? 'USER').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: DagacsColors.brandSoft,
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: DagacsColors.brandDark,
        ),
      ),
    );
  }
}

/// A consistent rounded content card. When [onTap] is provided the whole card
/// is tappable with a Material ripple and [key] is applied to the ink area
/// (widget tests tap by that key).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(DagacsSpace.lg),
    required this.child,
  });

  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// Feature navigation card: leading icon badge, title, optional subtitle and a
/// chevron — the consistent tile used across home, hub and lists.
class AppFeatureTile extends StatelessWidget {
  const AppFeatureTile({
    super.key,
    required this.icon,
    this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DagacsSpace.lg,
        vertical: 14,
      ),
      child: Row(
        children: [
          AppIconBadge(icon: icon),
          const SizedBox(width: DagacsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
                if (subtitle != null) ...[
                  if (title != null) const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Icon(Icons.chevron_right, color: DagacsColors.textSecondary),
        ],
      ),
    );
  }
}

/// Consistent empty-state block. [key] lands on the outer element so tests can
/// find it (e.g. `department-empty`).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DagacsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(
              icon: icon,
              color: DagacsColors.textSecondary,
              backgroundColor: DagacsColors.surfaceAlt,
              size: 64,
            ),
            const SizedBox(height: DagacsSpace.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DagacsTextStyles.body
                  .copyWith(color: DagacsColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent error block with a Retry action.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
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
        padding: const EdgeInsets.all(DagacsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(
              icon: Icons.cloud_off_outlined,
              color: DagacsColors.error,
              backgroundColor: DagacsColors.errorBg,
              size: 64,
            ),
            const SizedBox(height: DagacsSpace.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DagacsTextStyles.body,
            ),
            const SizedBox(height: DagacsSpace.lg),
            AppPrimaryButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent primary action button using the DAGACS brand palette.
///
/// Uses the existing [ElevatedButton] theme so it adapts to the
/// [DagacsTheme] automatically. The [loading] state disables the
/// button and shows an inline spinner.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    this.child,
    this.loading = false,
  });

  final VoidCallback onPressed;
  final Widget? child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : child,
      ),
    );
  }
}

/// Secondary/outlined action button using the DAGACS outline palette.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.onPressed,
    this.child,
    this.loading = false,
  });

  final VoidCallback onPressed;
  final Widget? child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: DagacsColors.brandPrimary,
                ),
              )
            : child,
      ),
    );
  }
}

/// Destructive/danger action button using the DAGACS error palette.
class AppDangerButton extends StatelessWidget {
  const AppDangerButton({
    super.key,
    required this.onPressed,
    this.child,
    this.loading = false,
  });

  final VoidCallback onPressed;
  final Widget? child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: DagacsColors.error,
          foregroundColor: Colors.white,
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : child,
      ),
    );
  }
}

/// Stat card for dashboard metric display.
///
/// Displays a leading icon badge, a numeric value, a label, and an
/// optional subtitle. Designed for [AppResponsiveGrid] layouts.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.subtitle,
    this.iconColor = DagacsColors.brandPrimary,
    this.iconBackgroundColor = DagacsColors.brandSoft,
    this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? subtitle;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DagacsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: icon,
            color: iconColor,
            backgroundColor: iconBackgroundColor,
            size: 44,
          ),
          const SizedBox(height: DagacsSpace.md),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: valueColor ?? DagacsColors.textPrimary,
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
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DagacsTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// Consistent filter bar with a search field and optional trailing action.
///
/// [searchController] drives the search input. [onChanged] receives
/// the current query string. [trailing] is placed at the right end
/// (e.g. a filter chip row or action button).
class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    required this.searchController,
    required this.onChanged,
    this.hintText = 'Search…',
    this.trailing,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        DagacsSpace.sm,
        DagacsSpace.lg,
        DagacsSpace.sm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: searchController,
                onChanged: onChanged,
                hintText: hintText,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: DagacsSpace.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Responsive table wrapper that enables horizontal scrolling on
/// narrow screens while preserving [DataTable] semantics on desktop.
///
/// The table always renders with the full column set; on mobile the
/// content scrolls horizontally rather than clipping or wrapping.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.dataRowHeight = 48,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double dataRowHeight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        dataRowMinHeight: dataRowHeight,
        dataRowMaxHeight: dataRowHeight,
        headingRowHeight: 48,
        horizontalMargin: 0,
        columnSpacing: DagacsSpace.lg,
        dataRowColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return DagacsColors.brandSoft;
            }
            return null;
          },
        ),
      ),
    );
  }
}

/// Centers constrained content on wide (desktop) screens so rows never stretch
/// awkwardly across the full browser width.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DagacsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: DagacsSpace.lg),
              Text(
                message!,
                style:
                    const TextStyle(color: DagacsColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status pill (used for student ACTIVE / INACTIVE).
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.active = true,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toUpperCase();
    final isNegative = normalized == 'ABSENT' || normalized == 'CANCELLED' ||
        normalized == 'INACTIVE';
    final isWarning = normalized == 'SCHEDULED' || normalized == 'UNMARKED';
    final background = isNegative
        ? DagacsColors.errorBg
        : isWarning || !active
            ? DagacsColors.warningBg
            : DagacsColors.successBg;
    final foreground = isNegative
        ? DagacsColors.error
        : isWarning || !active
            ? DagacsColors.warning
            : DagacsColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
      ),
      child: Semantics(
        label: 'Status: $label',
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// A compact, local-data search field. It deliberately exposes only a text
/// callback: screens with already-loaded records can filter without inventing
/// unsupported backend query parameters.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_outlined),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

/// One confirmation treatment for destructive actions. The action only
/// resolves `true` after the user explicitly chooses the destructive button.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.confirmKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded,
          color: DagacsColors.warning),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: confirmKey,
          style: TextButton.styleFrom(foregroundColor: DagacsColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Page-level header: icon, title, optional subtitle and trailing action.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIconBadge(icon: icon!),
          const SizedBox(width: DagacsSpace.lg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: theme.textTheme.titleLarge ??
                      DagacsTextStyles.screenTitle,
                ),
              ],
              if (subtitle != null) ...[
                if (title != null) const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall ??
                      DagacsTextStyles.caption,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DagacsSpace.lg,
        DagacsSpace.lg,
        DagacsSpace.lg,
        DagacsSpace.md,
      ),
      child: row,
    );
  }
}

/// Themed text form field shared by every target form (keys and validators are
/// injected by the caller and preserved verbatim).
class AppFormTextField extends StatelessWidget {
  const AppFormTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.hintText,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final String? hintText;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DagacsSpace.md),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textInputAction: textInputAction,
        readOnly: readOnly,
        onTap: onTap,
        autofocus: autofocus,
        focusNode: focusNode,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon:
              prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

/// Themed dropdown field shared by every target form.
class AppFormDropdown<T> extends StatelessWidget {
  const AppFormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DagacsSpace.md),
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

/// Rounded dialog scaffold with a consistent max width and scrollable body.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    this.width = 480,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DagacsSpace.lg,
        vertical: DagacsSpace.xl,
      ),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DagacsSpace.xl),
          child: child,
        ),
      ),
    );
  }
}

/// Consistent dialog action row: Cancel on the left, themed submit (with an
/// inline loading state while [submitting]) on the right.
class AppFormActions extends StatelessWidget {
  const AppFormActions({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    required this.submitting,
    required this.submitKey,
    required this.submitLabel,
  });

  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final bool submitting;
  final String submitKey;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DagacsSpace.sm,
      runSpacing: DagacsSpace.sm,
      children: [
        TextButton(
          onPressed: submitting ? null : onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: Key(submitKey),
          onPressed: submitting ? null : onSubmit,
          child: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(submitLabel),
        ),
      ],
    );
  }
}

/// Centers constrained content on wide (desktop) screens so rows never stretch
/// awkwardly across the full browser width.
class AppConstrainedMax extends StatelessWidget {
  const AppConstrainedMax({
    super.key,
    this.maxWidth = 1080,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Responsive grid helper for the target list/dashboard screens.
class AppResponsiveGrid extends StatelessWidget {
  const AppResponsiveGrid({
    super.key,
    required this.children,
    this.crossAxisCount,
    this.gap = DagacsSpace.md,
  });

  final List<Widget> children;
  final int? crossAxisCount;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = crossAxisCount ??
            DagacsBreakpoints.columnsFor(constraints.maxWidth);
        final width = (constraints.maxWidth - gap * (columns - 1)) /
            columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

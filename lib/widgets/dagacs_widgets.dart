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
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
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
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
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
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent full-screen loading block.
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
    final background =
        active ? DagacsColors.successBg : DagacsColors.warningBg;
    final foreground =
        active ? DagacsColors.success : DagacsColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Page-level header: icon, title, optional subtitle and trailing action.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData? icon;
  final String title;
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
              Text(
                title,
                style: theme.textTheme.titleLarge ??
                    DagacsTextStyles.screenTitle,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
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
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;

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
        decoration: InputDecoration(
          labelText: label,
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
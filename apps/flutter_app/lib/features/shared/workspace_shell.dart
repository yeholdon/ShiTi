import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/telegram_palette.dart';

EdgeInsets workspacePagePadding(
  BuildContext context, {
  double mobile = 16,
  double tablet = 20,
  double desktop = 24,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final value = width < 640
      ? mobile
      : width < 1024
          ? tablet
          : desktop;
  return EdgeInsets.all(value);
}

EdgeInsets workspacePanelPadding(
  BuildContext context, {
  double mobile = 16,
  double tablet = 18,
  double desktop = 20,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final value = width < 640
      ? mobile
      : width < 1024
          ? tablet
          : desktop;
  return EdgeInsets.all(value);
}

EdgeInsets workspaceHeroPanelPadding(BuildContext context) {
  return workspacePanelPadding(
    context,
    mobile: 18,
    tablet: 20,
    desktop: 24,
  );
}

double workspaceContentMaxWidth(
  BuildContext context, {
  double desktop = 1360,
  double wideDesktop = 1480,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1680) {
    return wideDesktop;
  }
  if (width >= 1200) {
    return desktop;
  }
  return width;
}

Widget workspaceConstrainedContent(
  BuildContext context, {
  required Widget child,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: workspaceContentMaxWidth(context),
      ),
      child: child,
    ),
  );
}

class WorkspaceBackdrop extends StatelessWidget {
  const WorkspaceBackdrop({
    required this.child,
    this.padding = const EdgeInsets.all(0),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF7FBFF),
            TelegramPalette.shell,
            Color(0xFFE5EFF8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            left: -60,
            child: _GlowOrb(
              size: 260,
              color: Color(0x553390EC),
            ),
          ),
          const Positioned(
            top: 120,
            right: -40,
            child: _GlowOrb(
              size: 220,
              color: Color(0x40FFFFFF),
            ),
          ),
          const Positioned(
            bottom: -80,
            right: 60,
            child: _GlowOrb(
              size: 240,
              color: Color(0x3067B7FF),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x10FFFFFF), Color(0x00FFFFFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.backgroundColor = TelegramPalette.surfaceRaised,
    this.borderColor = TelegramPalette.border,
    this.elevation = 0,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      elevation: elevation,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

class WorkspaceGlassPanel extends StatelessWidget {
  const WorkspaceGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 30,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.white.withValues(alpha: 0.72),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class WorkspaceEyebrow extends StatelessWidget {
  const WorkspaceEyebrow({
    required this.label,
    this.icon,
    this.foregroundColor = TelegramPalette.accentDark,
    this.backgroundColor = TelegramPalette.surfaceAccent,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceMetricPill extends StatelessWidget {
  const WorkspaceMetricPill({
    required this.label,
    required this.value,
    this.highlight = false,
    super.key,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final background = highlight
        ? TelegramPalette.accent.withValues(alpha: 0.1)
        : TelegramPalette.surfaceSoft;
    final border =
        highlight ? TelegramPalette.borderAccent : TelegramPalette.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: TelegramPalette.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: TelegramPalette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceInfoPill extends StatelessWidget {
  const WorkspaceInfoPill({
    required this.value,
    this.label,
    this.icon,
    this.highlight = false,
    super.key,
  });

  final String? label;
  final String value;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        highlight ? TelegramPalette.accentDark : TelegramPalette.textStrong;
    final backgroundColor =
        highlight ? TelegramPalette.warningSurface : TelegramPalette.surfaceAccent;
    final borderColor =
        highlight ? TelegramPalette.warningBorder : TelegramPalette.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 8),
          ],
          Text(
            label == null || label!.trim().isEmpty ? value : '${label!}：$value',
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceFilterPill extends StatelessWidget {
  const WorkspaceFilterPill({
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.showSelectedCheckmark = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool showSelectedCheckmark;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foregroundColor = enabled
        ? (selected
            ? TelegramPalette.accentDark
            : TelegramPalette.textMuted)
        : TelegramPalette.textSoft;
    final backgroundColor = enabled
        ? (selected
            ? TelegramPalette.surfaceAccent
            : TelegramPalette.highlight)
        : TelegramPalette.surfaceSoft;
    final borderColor = enabled
        ? (selected
            ? TelegramPalette.borderAccent
            : TelegramPalette.border)
        : TelegramPalette.border;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foregroundColor),
                  const SizedBox(width: 6),
                ] else if (selected && showSelectedCheckmark) ...[
                  Icon(Icons.check_rounded, size: 16, color: foregroundColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceMessageBanner extends StatelessWidget {
  const WorkspaceMessageBanner({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    this.title,
    this.message,
    this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  }) : assert(
         message != null || child != null,
         'WorkspaceMessageBanner requires a message or child.',
       );

  const WorkspaceMessageBanner.error({
    required this.message,
    this.title,
    this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  }) : icon = Icons.error_outline,
       foregroundColor = TelegramPalette.errorText,
       backgroundColor = TelegramPalette.errorSurface,
       borderColor = TelegramPalette.errorBorder;

  const WorkspaceMessageBanner.info({
    this.child,
    this.title,
    this.message,
    this.padding = const EdgeInsets.all(14),
    super.key,
  }) : icon = Icons.info_outline,
       foregroundColor = TelegramPalette.textStrong,
       backgroundColor = TelegramPalette.surfaceAccent,
       borderColor = TelegramPalette.border;

  const WorkspaceMessageBanner.warning({
    required this.message,
    this.title,
    this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  }) : icon = Icons.warning_amber_rounded,
       foregroundColor = TelegramPalette.warningText,
       backgroundColor = TelegramPalette.warningSurface,
       borderColor = TelegramPalette.warningBorder;

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final String? title;
  final String? message;
  final Widget? child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: padding,
      borderRadius: 16,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: foregroundColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (message != null)
                  Text(
                    message!,
                    style: TextStyle(
                      color: foregroundColor,
                      height: 1.4,
                    ),
                  ),
                if (child != null) child!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceBulletPoint extends StatelessWidget {
  const WorkspaceBulletPoint({
    required this.text,
    this.icon = Icons.check_circle_outline,
    this.color = TelegramPalette.accentDark,
    super.key,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              height: 1.45,
              color: TelegramPalette.textStrong,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

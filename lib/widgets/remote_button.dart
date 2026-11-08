import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_key.dart';
import '../services/tv_controller.dart';

/// Bouton tactile standardisé pour la télécommande.
/// Déclenche systématiquement un retour haptique léger et transmet la commande au [TvController].
class RemoteButton extends ConsumerWidget {
  const RemoteButton({
    super.key,
    required this.remoteKey,
    this.icon,
    this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.fontSize,
  }) : assert(icon != null || label != null, 'Un bouton doit posséder une icône ou un libellé textuel');

  final RemoteKey remoteKey;
  final IconData? icon;
  final String? label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final double? fontSize;

  void _handlePress(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    ref.read(tvControllerProvider).sendCommand(remoteKey);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final effectiveBg = backgroundColor ?? theme.colorScheme.surfaceContainerHigh;
    final effectiveFg = foregroundColor ?? theme.colorScheme.onSurface;

    final childContent = icon != null
        ? Icon(icon, color: effectiveFg, size: 24)
        : Text(
            label ?? remoteKey.label,
            style: TextStyle(
              color: effectiveFg,
              fontSize: fontSize ?? 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          );

    return Material(
      color: effectiveBg,
      shape: shape == BoxShape.circle
          ? const CircleBorder()
          : RoundedRectangleBorder(
              borderRadius: borderRadius ?? BorderRadius.circular(16),
            ),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black45,
      child: InkWell(
        onTap: () => _handlePress(context, ref),
        splashColor: theme.colorScheme.primary.withAlpha(50),
        highlightColor: theme.colorScheme.primary.withAlpha(25),
        child: SizedBox(
          width: width ?? 56,
          height: height ?? 56,
          child: Center(child: childContent),
        ),
      ),
    );
  }
}


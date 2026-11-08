import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_key.dart';
import '../services/tv_controller.dart';

/// Pavé directionnel ergonomique composé de 4 directions et d'un bouton OK central.
/// Dimensions : cercle de 240 dp avec bouton central OK de 88 dp.
class DpadWidget extends ConsumerWidget {
  const DpadWidget({super.key});

  void _pressKey(WidgetRef ref, RemoteKey key) {
    HapticFeedback.lightImpact();
    ref.read(tvControllerProvider).sendCommand(key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surfaceContainerHigh;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Flèche HAUT
            Positioned(
              top: 10,
              child: _DpadDirectionButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => _pressKey(ref, RemoteKey.up),
              ),
            ),
            // Flèche BAS
            Positioned(
              bottom: 10,
              child: _DpadDirectionButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => _pressKey(ref, RemoteKey.down),
              ),
            ),
            // Flèche GAUCHE
            Positioned(
              left: 10,
              child: _DpadDirectionButton(
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: () => _pressKey(ref, RemoteKey.left),
              ),
            ),
            // Flèche DROITE
            Positioned(
              right: 10,
              child: _DpadDirectionButton(
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: () => _pressKey(ref, RemoteKey.right),
              ),
            ),
            // Bouton OK au centre (88 dp)
            Material(
              color: surfaceColor,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black54,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _pressKey(ref, RemoteKey.ok),
                splashColor: theme.colorScheme.primary.withAlpha(80),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: onSurfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DpadDirectionButton extends StatelessWidget {
  const _DpadDirectionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withAlpha(50),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            icon,
            size: 38,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

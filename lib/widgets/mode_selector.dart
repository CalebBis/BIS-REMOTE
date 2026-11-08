import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_mode.dart';
import '../services/remote_mode_provider.dart';

/// Sélecteur de mode à 3 segments (Navigation, Pavé tactile, Chiffres).
/// Hauteur : 46 dp, padding interne : 5 dp.
/// Le segment actif affiche fond cyan (#00C8F0) avec icône et texte foncés.
/// Les segments inactifs affichent uniquement une icône grise.
class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(remoteModeProvider);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2223),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            mode: RemoteMode.navigation,
            icon: Icons.sports_esports_rounded,
            isSelected: currentMode == RemoteMode.navigation,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(remoteModeProvider.notifier).setMode(RemoteMode.navigation);
            },
          ),
          const SizedBox(width: 4),
          _Segment(
            mode: RemoteMode.touchpad,
            icon: Icons.touch_app_rounded,
            isSelected: currentMode == RemoteMode.touchpad,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(remoteModeProvider.notifier).setMode(RemoteMode.touchpad);
            },
          ),
          const SizedBox(width: 4),
          _Segment(
            mode: RemoteMode.numeric,
            icon: Icons.dialpad_rounded,
            isSelected: currentMode == RemoteMode.numeric,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(remoteModeProvider.notifier).setMode(RemoteMode.numeric);
            },
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.mode,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final RemoteMode mode;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeBgColor = Color(0xFF00C8F0);
    const activeFgColor = Color(0xFF111418);
    const inactiveFgColor = Color(0xFF8E999A);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
        ),
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeFgColor : inactiveFgColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                mode.label,
                style: const TextStyle(
                  color: activeFgColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/discovery_screen.dart';
import '../services/tv_controller.dart';

/// Bandeau informatif en tête d'écran indiquant le statut de connexion au téléviseur.
/// Cliquable pour ouvrir l'écran de découverte réseau et de sélection des téléviseurs.
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(tvConnectionStatusProvider);
    final selectedTv = ref.watch(selectedTvProvider);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2223),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
                );
              },
          splashColor: const Color(0xFF00C8F0).withAlpha(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(
                  selectedTv != null ? Icons.tv_rounded : Icons.tv_off_rounded,
                  size: 20,
                  color: selectedTv != null
                      ? const Color(0xFF00C8F0)
                      : const Color(0xFF8E999A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selectedTv != null
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: const Color(0xFFE3E8E8),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF555F61),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

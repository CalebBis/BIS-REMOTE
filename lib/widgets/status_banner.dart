import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tv_controller.dart';

/// Bandeau informatif en tête d'écran indiquant le statut de connexion au téléviseur.
/// Conçu sous forme de pill étirée de 56 dp de hauteur pour s'aligner avec le bouton Power.
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(tvConnectionStatusProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
      child: Row(
        children: [
          const Icon(
            Icons.tv_off_rounded,
            size: 20,
            color: Color(0xFF8E999A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE3E8E8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

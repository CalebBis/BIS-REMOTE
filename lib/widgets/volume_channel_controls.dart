import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_key.dart';
import '../services/tv_controller.dart';
import 'remote_button.dart';
import 'text_input_sheet.dart';

/// Module regroupant sur une seule ligne les rockers verticaux Volume (84 x 172 dp),
/// Chaînes (84 x 172 dp) et au centre les deux boutons ronds (60 dp) Muet et Texte.
class VolumeChannelControls extends ConsumerWidget {
  const VolumeChannelControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textColor = Color(0xFF8E999A);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rocker Volume gauche (84 x 172 dp)
        const _RockerWidget(
          topKey: RemoteKey.volumeUp,
          topIcon: Icons.add_rounded,
          bottomKey: RemoteKey.volumeDown,
          bottomIcon: Icons.remove_rounded,
          label: 'VOL',
        ),

        // Centre : Muet + Texte côte à côte
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton Muet (60 dp)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RemoteButton(
                  remoteKey: RemoteKey.mute,
                  icon: Icons.volume_off_rounded,
                  shape: BoxShape.circle,
                  width: 60,
                  height: 60,
                  backgroundColor: Color(0xFF262D2E),
                  foregroundColor: Color(0xFFA01818),
                ),
                SizedBox(height: 6),
                Text(
                  'Muet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Bouton Texte (60 dp, icône cyan, contour fin cyan translucide)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262D2E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x6600C8F0),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        TextInputSheet.show(context);
                      },
                      splashColor: const Color(0xFF00C8F0).withAlpha(50),
                      child: const Center(
                        child: Icon(
                          Icons.keyboard_outlined,
                          color: Color(0xFF00C8F0),
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Texte',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Rocker Chaînes droite (84 x 172 dp)
        const _RockerWidget(
          topKey: RemoteKey.channelUp,
          topIcon: Icons.keyboard_arrow_up_rounded,
          bottomKey: RemoteKey.channelDown,
          bottomIcon: Icons.keyboard_arrow_down_rounded,
          label: 'CH',
        ),
      ],
    );
  }
}

class _RockerWidget extends ConsumerWidget {
  const _RockerWidget({
    required this.topKey,
    required this.topIcon,
    required this.bottomKey,
    required this.bottomIcon,
    required this.label,
  });

  final RemoteKey topKey;
  final IconData topIcon;
  final RemoteKey bottomKey;
  final IconData bottomIcon;
  final String label;

  void _press(WidgetRef ref, RemoteKey key) {
    HapticFeedback.lightImpact();
    ref.read(tvControllerProvider).sendCommand(key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 84,
      height: 172,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2223),
        borderRadius: BorderRadius.circular(42),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bouton haut (+)
          Expanded(
            child: Material(
              color: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _press(ref, topKey),
                splashColor: const Color(0xFF00C8F0).withAlpha(50),
                child: Center(
                  child: Icon(topIcon, color: const Color(0xFFE3E8E8), size: 30),
                ),
              ),
            ),
          ),
          // Libellé central (VOL ou CH)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF7FD6DC),
              ),
            ),
          ),
          // Bouton bas (-)
          Expanded(
            child: Material(
              color: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(42)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _press(ref, bottomKey),
                splashColor: const Color(0xFF00C8F0).withAlpha(50),
                child: Center(
                  child: Icon(bottomIcon, color: const Color(0xFFE3E8E8), size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

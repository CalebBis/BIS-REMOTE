import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_key.dart';
import '../models/remote_mode.dart';
import '../services/remote_mode_provider.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/mode_selector.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/playback_controls.dart';
import '../widgets/remote_button.dart';
import '../widgets/status_banner.dart';
import '../widgets/touchpad_widget.dart';
import '../widgets/volume_channel_controls.dart';

/// Écran principal de la télécommande universelle.
/// Respecte rigoureusement la maquette validée :
/// 1. Bandeau TV + bouton Power (56 dp)
/// 2. Bloc Retour / Accueil / Menu (carte arrondie rayon 28, boutons 52 dp)
/// 3. Zone centrale fixe (240 dp) avec transition animée (AnimatedSwitcher)
/// 4. Sélecteur de mode centré (46 dp)
/// 5. Ligne unique Volume / Muet + Texte / Chaînes
/// 6. Contrôles média (Précédent 60 dp, Play/Pause 84 dp, Suivant 60 dp)
class RemoteScreen extends ConsumerWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(remoteModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Bandeau TV (pill étirée) + bouton Power rond rouge (56 dp)
              Row(
                children: const [
                  Expanded(
                    child: StatusBanner(),
                  ),
                  SizedBox(width: 12),
                  RemoteButton(
                    remoteKey: RemoteKey.power,
                    icon: Icons.power_settings_new_rounded,
                    shape: BoxShape.circle,
                    width: 56,
                    height: 56,
                    backgroundColor: Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Bloc Retour / Accueil / Menu : carte arrondie (rayon 28), 3 boutons de 52 dp
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    _SystemActionButton(
                      remoteKey: RemoteKey.back,
                      icon: Icons.arrow_back_rounded,
                      label: 'Retour',
                    ),
                    _SystemActionButton(
                      remoteKey: RemoteKey.home,
                      icon: Icons.home_rounded,
                      label: 'Accueil',
                    ),
                    _SystemActionButton(
                      remoteKey: RemoteKey.menu,
                      icon: Icons.menu_rounded,
                      label: 'Menu',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. ZONE CENTRALE : hauteur FIXE de 240 dp avec AnimatedSwitcher
              SizedBox(
                height: 240,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildCentralZone(mode),
                ),
              ),

              const SizedBox(height: 16),

              // 4. SÉLECTEUR DE MODE centré (pill 46 dp)
              const Center(child: ModeSelector()),

              const SizedBox(height: 22),

              // 5. LIGNE VOLUME / MUET + TEXTE / CHAÎNES (sur une seule ligne)
              const VolumeChannelControls(),

              const SizedBox(height: 22),

              // 6. CONTRÔLES MÉDIA en bas (Précédent 60 dp, Play/Pause 84 dp, Suivant 60 dp)
              const PlaybackControls(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentralZone(RemoteMode mode) {
    switch (mode) {
      case RemoteMode.navigation:
        return const KeyedSubtree(
          key: ValueKey('mode_nav'),
          child: DpadWidget(),
        );
      case RemoteMode.touchpad:
        return const KeyedSubtree(
          key: ValueKey('mode_touchpad'),
          child: TouchpadWidget(),
        );
      case RemoteMode.numeric:
        return const KeyedSubtree(
          key: ValueKey('mode_numeric'),
          child: NumericKeypad(),
        );
    }
  }
}

class _SystemActionButton extends StatelessWidget {
  const _SystemActionButton({
    required this.remoteKey,
    required this.icon,
    required this.label,
  });

  final RemoteKey remoteKey;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RemoteButton(
          remoteKey: remoteKey,
          icon: icon,
          shape: BoxShape.circle,
          width: 52,
          height: 52,
          backgroundColor: const Color(0xFF262D2E),
          foregroundColor: const Color(0xFFE3E8E8),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8E999A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

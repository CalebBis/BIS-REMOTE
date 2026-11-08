import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_tv.dart';
import '../models/remote_key.dart';
import '../models/remote_mode.dart';
import '../services/android_tv_pairing_service.dart';
import '../services/tv_controller.dart';
import '../services/wake_on_lan_service.dart';
import 'discovery_screen.dart';
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
class RemoteScreen extends ConsumerStatefulWidget {
  const RemoteScreen({super.key});

  @override
  ConsumerState<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends ConsumerState<RemoteScreen> with WidgetsBindingObserver {
  Timer? _wakeRetryTimer;
  bool _isWakingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(selectedTvProvider.notifier).loadSavedTv();
    });
  }

  @override
  void dispose() {
    _wakeRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handlePowerPress() async {
    final selectedTv = ref.read(selectedTvProvider);
    if (selectedTv == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucune TV sélectionnée'),
          action: SnackBarAction(
            label: 'Rechercher',
            textColor: const Color(0xFF00C8F0),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    final connState = selectedTv.brand == TvBrand.androidTv
        ? ref.read(androidTvConnectionStateProvider)
        : AndroidTvConnectionState.connected;

    final isConnected = connState == AndroidTvConnectionState.connected;

    if (isConnected) {
      // Connectée : transmission normale de la commande Power
      ref.read(tvControllerProvider).sendCommand(RemoteKey.power);
      return;
    }

    // Hors ligne : vérification de l'adresse MAC
    final mac = selectedTv.macAddress;
    if (mac == null || mac.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ajoutez l\'adresse MAC de la TV pour pouvoir l\'allumer'),
          backgroundColor: const Color(0xFF1B2223),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Configurer',
            textColor: const Color(0xFF00C8F0),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    // Réveil par Wake-on-LAN
    final wol = ref.read(wakeOnLanServiceProvider);
    await wol.wakeTv(mac);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Réveil de la TV…'),
        backgroundColor: Color(0xFF00525A),
        duration: Duration(seconds: 3),
      ),
    );

    // Relance de la reconnexion avec fréquence augmentée pendant 40 secondes
    _startWakeupRetry(selectedTv);
  }

  void _startWakeupRetry(DiscoveredTv tv) {
    if (_isWakingUp) return;
    _isWakingUp = true;
    _wakeRetryTimer?.cancel();

    int elapsedSeconds = 0;
    const interval = Duration(seconds: 3);
    const maxDuration = Duration(seconds: 40);

    // Tentative de reconnexion immédiate
    ref.invalidate(androidTvControllerProvider(tv.ip));

    _wakeRetryTimer = Timer.periodic(interval, (timer) {
      elapsedSeconds += interval.inSeconds;

      final currentState = ref.read(androidTvConnectionStateProvider);
      if (currentState == AndroidTvConnectionState.connected) {
        timer.cancel();
        _isWakingUp = false;
        debugPrint('[WakeOnLan] TV réveillée et connectée en $elapsedSeconds secondes.');
        return;
      }

      if (elapsedSeconds >= maxDuration.inSeconds) {
        timer.cancel();
        _isWakingUp = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La TV ne répond pas. Vérifiez que le réveil par réseau est activé dans ses paramètres.'),
              backgroundColor: Color(0xFFB71C1C),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Tentative de reconnexion accélérée
      ref.invalidate(androidTvControllerProvider(tv.ip));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final selectedTv = ref.read(selectedTvProvider);
    if (selectedTv == null) return;

    if (state == AppLifecycleState.resumed) {
      debugPrint('[AutoConnect] Reprise au premier plan (resumed). Vérification de la connexion...');
      final connState = ref.read(androidTvConnectionStateProvider);
      if (selectedTv.brand == TvBrand.androidTv && connState != AndroidTvConnectionState.connected) {
        debugPrint('[AutoConnect] Reconnexion automatique à ${selectedTv.ip}...');
        ref.invalidate(androidTvControllerProvider(selectedTv.ip));
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      debugPrint('[AutoConnect] Passage en arrière-plan prolongé ($state). Fermeture propre de la connexion...');
      if (selectedTv.brand == TvBrand.androidTv) {
        try {
          final controller = ref.read(androidTvControllerProvider(selectedTv.ip));
          controller.disconnect();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                children: [
                  const Expanded(
                    child: StatusBanner(),
                  ),
                  const SizedBox(width: 12),
                  RemoteButton(
                    remoteKey: RemoteKey.power,
                    icon: Icons.power_settings_new_rounded,
                    shape: BoxShape.circle,
                    width: 56,
                    height: 56,
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    onPressed: _handlePowerPress,
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

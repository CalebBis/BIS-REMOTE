import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_key.dart';
import '../services/tv_controller.dart';
import 'remote_button.dart';

/// Pavé numérique (0 à 9) dans une carte arrondie de 240 dp de haut,
/// incluant un bouton de suppression avec répétition automatique (appui long).
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Ligne 1 : 1, 2, 3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              RemoteButton(remoteKey: RemoteKey.digit1, label: '1', shape: BoxShape.circle, width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit2, label: '2', shape: BoxShape.circle, width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit3, label: '3', shape: BoxShape.circle, width: 48, height: 48),
            ],
          ),
          // Ligne 2 : 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              RemoteButton(remoteKey: RemoteKey.digit4, label: '4', shape: BoxShape.circle, width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit5, label: '5', shape: BoxShape.circle, width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit6, label: '6', shape: BoxShape.circle, width: 48, height: 48),
            ],
          ),
          // Ligne 3 : 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              RemoteButton(remoteKey: RemoteKey.digit7, label: '7', shape: BoxShape.circle, width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit8, label: '8', shape: BoxShape.circle, width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit9, label: '9', shape: BoxShape.circle, width: 48, height: 48),
            ],
          ),
          // Ligne 4 : Bouton Supprimer à gauche, 0 au centre, espace vide à droite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _BackspaceButton(),
              RemoteButton(remoteKey: RemoteKey.digit0, label: '0', shape: BoxShape.circle, width: 48, height: 48),
              SizedBox(width: 48, height: 48),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bouton rond de suppression (48 dp) avec retour haptique et répétition continue sur appui long.
class _BackspaceButton extends ConsumerStatefulWidget {
  const _BackspaceButton();

  @override
  ConsumerState<_BackspaceButton> createState() => _BackspaceButtonState();
}

class _BackspaceButtonState extends ConsumerState<_BackspaceButton> {
  Timer? _initialHoldTimer;
  Timer? _repeatTimer;

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _triggerBackspace() {
    HapticFeedback.lightImpact();
    ref.read(tvControllerProvider).sendBackspace();
  }

  void _handlePressDown() {
    _triggerBackspace();
    _stopTimers();

    // Délai initial avant d'entamer la répétition automatique
    _initialHoldTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        _triggerBackspace();
      });
    });
  }

  void _stopTimers() {
    _initialHoldTimer?.cancel();
    _initialHoldTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = theme.colorScheme.surfaceContainerHigh;
    final effectiveFg = theme.colorScheme.onSurface;

    return Semantics(
      label: 'Supprimer',
      button: true,
      child: Material(
        color: effectiveBg,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black45,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTapDown: (_) => _handlePressDown(),
          onTapUp: (_) => _stopTimers(),
          onTapCancel: () => _stopTimers(),
          onTap: () {}, // Permet le feedback visuel (splash/ripple) de InkWell
          splashColor: theme.colorScheme.primary.withAlpha(50),
          highlightColor: theme.colorScheme.primary.withAlpha(25),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.backspace_outlined,
                color: effectiveFg,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

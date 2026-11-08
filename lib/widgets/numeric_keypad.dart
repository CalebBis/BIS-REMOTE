import 'package:flutter/material.dart';
import '../models/remote_key.dart';
import 'remote_button.dart';

/// Pavé numérique (0 à 9) dans une carte arrondie de 240 dp de haut.
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
          // Ligne 4 : 0 au centre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              SizedBox(width: 48, height: 48),
              RemoteButton(remoteKey: RemoteKey.digit0, label: '0', shape: BoxShape.circle, width: 48, height: 48),
              SizedBox(width: 48, height: 48),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/remote_key.dart';
import 'remote_button.dart';

/// Barre de contrôle de lecture multimédia (Précédent 60 dp, Lecture/Pause 84 dp, Suivant 60 dp).
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        // Bouton Précédent (60 dp)
        RemoteButton(
          remoteKey: RemoteKey.previous,
          icon: Icons.skip_previous_rounded,
          shape: BoxShape.circle,
          width: 60,
          height: 60,
          backgroundColor: Color(0xFF262D2E),
          foregroundColor: Color(0xFFE3E8E8),
        ),

        // Bouton Lecture / Pause (84 dp, fond teal foncé #00525A, icône cyan clair)
        RemoteButton(
          remoteKey: RemoteKey.playPause,
          icon: Icons.play_arrow_rounded,
          shape: BoxShape.circle,
          width: 84,
          height: 84,
          backgroundColor: Color(0xFF00525A),
          foregroundColor: Color(0xFF00C8F0),
        ),

        // Bouton Suivant (60 dp)
        RemoteButton(
          remoteKey: RemoteKey.next,
          icon: Icons.skip_next_rounded,
          shape: BoxShape.circle,
          width: 60,
          height: 60,
          backgroundColor: Color(0xFF262D2E),
          foregroundColor: Color(0xFFE3E8E8),
        ),
      ],
    );
  }
}

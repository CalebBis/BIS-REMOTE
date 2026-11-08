/// Représente l'ensemble des touches disponibles sur la télécommande.
enum RemoteKey {
  // Alimentation
  power,

  // Navigation & Système
  up,
  down,
  left,
  right,
  ok,
  back,
  home,
  menu,

  // Contrôle du volume
  volumeUp,
  volumeDown,
  mute,

  // Contrôle des chaînes
  channelUp,
  channelDown,

  // Pavé numérique
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,

  // Contrôle des médias
  playPause,
  previous,
  next;

  /// Libellé lisible pour l'affichage ou le débogage.
  String get label {
    switch (this) {
      case RemoteKey.power:
        return 'POWER';
      case RemoteKey.up:
        return 'HAUT';
      case RemoteKey.down:
        return 'BAS';
      case RemoteKey.left:
        return 'GAUCHE';
      case RemoteKey.right:
        return 'DROITE';
      case RemoteKey.ok:
        return 'OK';
      case RemoteKey.back:
        return 'RETOUR';
      case RemoteKey.home:
        return 'ACCUEIL';
      case RemoteKey.menu:
        return 'MENU';
      case RemoteKey.volumeUp:
        return 'VOL +';
      case RemoteKey.volumeDown:
        return 'VOL -';
      case RemoteKey.mute:
        return 'MUET';
      case RemoteKey.channelUp:
        return 'CH +';
      case RemoteKey.channelDown:
        return 'CH -';
      case RemoteKey.digit0:
        return '0';
      case RemoteKey.digit1:
        return '1';
      case RemoteKey.digit2:
        return '2';
      case RemoteKey.digit3:
        return '3';
      case RemoteKey.digit4:
        return '4';
      case RemoteKey.digit5:
        return '5';
      case RemoteKey.digit6:
        return '6';
      case RemoteKey.digit7:
        return '7';
      case RemoteKey.digit8:
        return '8';
      case RemoteKey.digit9:
        return '9';
      case RemoteKey.playPause:
        return 'LECTURE / PAUSE';
      case RemoteKey.previous:
        return 'PRÉCÉDENT';
      case RemoteKey.next:
        return 'SUIVANT';
    }
  }
}


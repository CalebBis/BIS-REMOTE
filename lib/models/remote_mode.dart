/// Représente le mode de contrôle actif de la zone centrale.
enum RemoteMode {
  /// Navigation par pavé directionnel classique (D-Pad + OK).
  navigation,

  /// Contrôle par pavé tactile (touchpad) avec curseur et gestes.
  touchpad,

  /// Pavé numérique direct (chiffres 0 à 9).
  numeric;

  /// Libellé pour l'affichage dans le sélecteur.
  String get label {
    switch (this) {
      case RemoteMode.navigation:
        return 'Navigation';
      case RemoteMode.touchpad:
        return 'Pavé tactile';
      case RemoteMode.numeric:
        return 'Chiffres';
    }
  }
}


# BisTv Remote

Télécommande universelle de télévision pilotée depuis un smartphone Android via le réseau Wi-Fi local.

## Fonctionnalités

- **Découverte automatique** des téléviseurs sur le réseau (SSDP / mDNS)
- **Ajout manuel** d'une TV par adresse IP
- **Appairage Android TV / Google TV** : génération du certificat client TLS et saisie du code PIN affiché à l'écran (port 6467)
- **Connexion TLS persistante** au téléviseur appairé (port 6466), avec reconnexion automatique et délai croissant
- **Mémorisation de la dernière TV** : au lancement, l'app se reconnecte automatiquement sans repasser par l'écran de découverte
- **Trois modes de télécommande** :
  - 🕹️ **D-Pad** : navigation directionnelle, OK, retour, accueil, menu, volume, chaînes
  - 👆 **Pavé tactile** : glisser pour naviguer, appuyer pour valider
  - 🔢 **Pavé numérique** : chiffres 0–9 pour saisir un numéro de chaîne directement
- **Allumage à distance (Wake-on-LAN)** : réveille la TV en veille profonde via un paquet magique UDP envoyé en broadcast (ports 7 et 9), si l'adresse MAC Wi-Fi de la TV a été configurée
- **Scan de récupération d'IP** : si la connexion échoue plusieurs fois, l'app scanne silencieusement le réseau pour retrouver la TV à sa nouvelle adresse
- **Gestion du cycle de vie** : reconnexion automatique quand l'app revient au premier plan ; fermeture propre de la connexion en arrière-plan prolongé
- **Action "Oublier cette TV"** dans l'écran de découverte (appui long) pour effacer la TV mémorisée et son certificat

## Prérequis

- Flutter ≥ 3.x / Dart ≥ 3.x
- Android SDK (minSdkVersion 21)
- Téléviseur Android TV ou Google TV sur le même réseau Wi-Fi local

## Commandes utiles

```bash
# Lancer l'application en mode debug
flutter run

# Exécuter les tests unitaires
flutter test

# Vérifier la qualité du code (aucune erreur attendue)
flutter analyze
```

## Architecture

```
lib/
├── main.dart                        # Point d'entrée, orientation, barre d'état
├── models/
│   ├── discovered_tv.dart           # Modèle TV (nom, IP, marque, port, MAC)
│   ├── remote_key.dart              # Enumération des touches de la télécommande
│   └── remote_mode.dart             # Énumération des modes de contrôle (navigation, touchpad, numeric)
├── screens/
│   ├── remote_screen.dart           # Écran principal de la télécommande
│   └── discovery_screen.dart        # Écran de découverte et d'appairage
├── services/
│   ├── tv_controller.dart           # Interface abstraite TvController
│   ├── mock_tv_controller.dart      # Contrôleur fictif (aucune TV sélectionnée)
│   ├── android_tv_controller.dart   # Contrôleur Android TV (TLS, protobuf)
│   ├── tv_discovery_provider.dart   # Riverpod : état global et persistance
│   ├── pairing_service.dart         # Appairage TLS (port 6467, certificat client)
│   ├── certificate_storage.dart     # Stockage sécurisé des certificats (flutter_secure_storage)
│   ├── discovery_service.dart       # Découverte SSDP / mDNS
│   └── wake_on_lan_service.dart     # Construction et envoi du paquet magique UDP
└── widgets/
    ├── remote_button.dart           # Bouton générique de la télécommande
    ├── dpad_widget.dart             # Widget D-Pad (navigation directionnelle)
    ├── touchpad_widget.dart         # Widget pavé tactile
    └── numpad_widget.dart           # Widget pavé numérique
```

## Limitations connues

- **Une seule marque supportée** : Android TV / Google TV (protocole `androidtvremote2`). Les téléviseurs d'autres marques sont découverts mais ne peuvent pas encore être contrôlés.
- **Saisie de texte** : non disponible (le protocole de référence ne l'expose pas de manière fiable via la connexion de télécommande).
- **Wake-on-LAN** : nécessite que l'option "réveil par réseau" soit activée dans les paramètres réseau de la TV. Sur certains modèles, cette option se désactive après chaque mise à jour du firmware.
- **Pavé tactile** : fonctionne en mode flèches (pas de déplacement absolu du curseur).

## Licence

Usage personnel — aucune redistribution prévue.

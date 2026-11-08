# Journal des modifications (CHANGELOG_AI)

## [004] - Ajout des modes de contrôle (Navigation, Touchpad, Chiffres) et de la saisie de texte
- Date : 2026-11-08
- Demande : Ajout de trois modes de contrôle interchangeables dans une zone centrale fixe de 240 dp (Navigation D-Pad, Touchpad tactile avec gestes/fallback, Pavé numérique 0-9), sélecteur de mode animé sous forme de pill à 3 segments, intégration de la saisie de texte déportée via bottom sheet au-dessus du clavier virtuel, réorganisation de la ligne Volume/Muet+Texte/Chaînes et ajustement des contrôles média selon la maquette validée.
- Fichiers créés :
  - `lib/models/remote_mode.dart`
  - `lib/models/tv_capability.dart`
  - `lib/services/remote_mode_provider.dart`
  - `lib/widgets/touchpad_widget.dart`
  - `lib/widgets/mode_selector.dart`
  - `lib/widgets/text_input_sheet.dart`
- Fichiers modifiés :
  - `lib/services/tv_controller.dart`
  - `lib/widgets/dpad_widget.dart`
  - `lib/widgets/numeric_keypad.dart`
  - `lib/widgets/volume_channel_controls.dart`
  - `lib/widgets/playback_controls.dart`
  - `lib/widgets/status_banner.dart`
  - `lib/screens/remote_screen.dart`
  - `lib/main.dart`
  - `test/widget_test.dart`
  - `CHANGELOG_AI.md`
- Fichiers supprimés : Aucun
- Packages ajoutés : Aucun
- Détail :
  - `TvController` enrichi avec les capacités `TvCapability` (pointer, textInput) et méthodes associées (`sendPointerMove`, `sendPointerClick`, `sendScroll`, `sendText`, `sendBackspace`, `sendEnter`). `MockTvController` déclare ces deux capacités et logue toutes les interactions en console.
  - Modèle `RemoteMode` et provider Riverpod `remoteModeProvider` (mode par défaut: navigation).
  - Zone centrale fixe de 240 dp avec `AnimatedSwitcher` (fondu et léger zoom ~220 ms) permutant sans décalage vertical entre Dpad (240 dp, OK 88 dp), Touchpad (240 dp, throttle 90 ms, tap haptique, défilement 2 doigts, ripple visuel et mode flèches de secours si le pointeur est absent) et NumericKeypad (carte arrondie rayon 28, boutons 48 dp, 0 centré).
  - Sélecteur de mode centré `ModeSelector` : pill 46 dp à 3 segments avec indicateur cyan actif (`#00C8F0`), texte et icône, et icônes grises inactives.
  - Ligne unique Volume/Chaînes réajustée : rockers 84 x 172 dp et centre accueillant deux boutons ronds de 60 dp ("Muet" icône rouge foncé, "Texte" icône cyan avec bordure cyan translucide).
  - Bottom sheet `TextInputSheet` s'affichant au-dessus du clavier virtuel avec transmission en direct des caractères, suppression, validation Entrée et confirmation toast.
  - Barre de contrôle média calée sur les dimensions requises : Précédent (60 dp), Play/Pause (84 dp, fond teal #00525A, icône cyan clair), Suivant (60 dp).
  - Suppression de l'ancien accordéon dépliable de clavier numérique.
  - Adaptation des tests `widget_test.dart` vérifiant la navigation, le switch vers le touchpad, vers le pavé numérique et l'ouverture du sheet de saisie de texte.
- État : fonctionne
- À traiter : Implémentation future de la découverte réseau Wi-Fi / mDNS et des protocoles réels de TV (Samsung Tizen, LG webOS, Android TV).

## [003] - Création de l'application et de l'interface de télécommande universelle
- Date : 2026-11-07
- Demande : Création du projet Flutter (plateforme Android) avec Riverpod, Material 3 et thème sombre, et implémentation complète de l'interface de télécommande universelle (sans connexion réelle, sans DB, sans auth).
- Fichiers créés :
  - `pubspec.yaml`, `analysis_options.yaml`, arborescence Android
  - `lib/models/remote_key.dart`
  - `lib/services/tv_controller.dart`
  - `lib/widgets/remote_button.dart`
  - `lib/widgets/dpad_widget.dart`
  - `lib/widgets/volume_channel_controls.dart`
  - `lib/widgets/numeric_keypad.dart`
  - `lib/widgets/playback_controls.dart`
  - `lib/widgets/status_banner.dart`
  - `lib/screens/remote_screen.dart`
  - `test/widget_test.dart`
- Fichiers modifiés : `lib/main.dart`, `CHANGELOG_AI.md`
- Fichiers supprimés : Aucun
- Packages ajoutés :
  - `flutter_riverpod: ^3.3.2` : Gestion d'état requise par les règles d'architecture pour injecter et fournir le `TvController` et le statut de connexion.
- Détail :
  - Initialisation Flutter Android via `flutter create . --org com.bis --project-name bis_remote --platforms=android` en préservant l'ensemble des fichiers de règles et de configuration.
  - Modèle : Création de l'enum `RemoteKey` avec toutes les touches (Power, D-Pad, OK, Retour, Accueil, Menu, Vol+/-, Muet, Ch+/-, Pavé numérique 0-9, Play/Pause, Précédent, Suivant).
  - Service : Classe abstraite `TvController` (`sendCommand(RemoteKey key)`), implémentation `MockTvController` affichant les touches reçues dans la console de débogage, et providers Riverpod (`tvControllerProvider`, `tvConnectionStatusProvider`).
  - Widgets :
    - `RemoteButton` avec déclenchement automatique d'un retour haptique léger (`HapticFeedback.lightImpact()`) et appel de commande via Riverpod.
    - `DpadWidget` circulaire ergonomique (flèches et OK central).
    - `VolumeChannelControls` (rockers ergonomiques VOL, CH et bouton Muet).
    - `NumericKeypad` (pavé numérique 0-9).
    - `PlaybackControls` (Précédent, Play/Pause, Suivant).
    - `StatusBanner` indiquant "Aucune TV connectée".
  - Écran : `RemoteScreen` moderne, scrollable (`SingleChildScrollView`), optimisé pour utilisation à une main, avec bouton Power rouge bien visible et accordéon pour le pavé numérique.
  - Application : `BisRemoteApp` avec Material 3, `ProviderScope` et thème sombre par défaut.
- État : fonctionne
- À traiter : Implémentation future de la découverte réseau Wi-Fi / mDNS et des protocoles réels de TV (Samsung Tizen, LG webOS, Android TV).

## [002] - Ajout de la règle de workspace Always On
- Date : 2026-11-07
- Demande : Création de la règle de workspace .agent/rules/project-rules.md en mode Always On avec le contenu de PROJECT_RULES.md, sans supprimer d'autre fichier.
- Fichiers créés : .agent/rules/project-rules.md
- Fichiers modifiés : CHANGELOG_AI.md
- Fichiers supprimés : Aucun
- Packages ajoutés : Aucun
- Détail : Configuration de la règle de workspace permanente (.agent/rules/project-rules.md) avec métadonnées Always On (trigger: always_on / alwaysApply: true) contenant l'intégralité de PROJECT_RULES.md.
- État : fonctionne
- À traiter : Initialisation du projet Flutter (squelette d'application).

## [001] - Initialisation des règles du projet
- Date : 2026-11-07
- Demande : Création du système de mémoire du projet (PROJECT_RULES.md, CHANGELOG_AI.md et configuration de l'assistant IA).
- Fichiers créés : PROJECT_RULES.md, CHANGELOG_AI.md, AGENTS.md, .gemini/rules.md
- Fichiers modifiés : Aucun
- Fichiers supprimés : Aucun
- Packages ajoutés : Aucun
- Détail : Définition des règles de travail strictes, de la stack technique, de l'architecture cible et du format de rapport de passation. Enregistrement des consignes dans la configuration de l'outil IA. Aucun code Flutter n'a encore été créé.
- État : fonctionne
- À traiter : Initialisation du projet Flutter (squelette d'application).

---

## Décisions importantes
- **Périmètre immédiat** : Télécommande universelle TV via Wi-Fi. Pas de base de données, pas d'authentification (ne pas les anticiper).
- **Stack UI & State** : Flutter, Material 3, thème sombre par défaut, Riverpod pour la gestion d'état.
- **Organisation du code** : Structure stricte sous `lib/screens`, `lib/widgets`, `lib/models`, `lib/services`.
- **Architecture TV** : Classe abstraite `TvController`, avec une implémentation distincte pour chaque marque de TV.
- **Dépendances** : Aucun package externe ajouté sans justification préalable et documentée dans ce journal.
- **Discipline de travail** : Lecture intégrale préalable des règles et du journal, résumé en 2-3 lignes au début de chaque échange, modifications ciblées uniquement, vérification `flutter analyze`, mise à jour du journal et production d'un rapport de passation complet en fin de tâche.


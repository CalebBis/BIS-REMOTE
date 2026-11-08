---
trigger: always_on
description: "Règles permanentes du projet"
alwaysApply: true
---

# Règles du Projet

## Projet
- Application Flutter (Dart) de télécommande universelle de télévision, utilisée depuis un smartphone via le réseau Wi-Fi.
- Pour l'instant : pas de base de données, pas d'authentification (ça viendra plus tard, ne pas les anticiper).

## Stack et architecture
- Flutter, Material 3, thème sombre par défaut, Riverpod pour la gestion d'état.
- Dossiers : `lib/screens`, `lib/widgets`, `lib/models`, `lib/services`.
- Les TV sont pilotées via une classe abstraite `TvController` ; chaque marque a sa propre implémentation.
- Pas de package ajouté sans justification écrite dans le journal.

## Règles de travail (obligatoires)
1. AVANT chaque modification, tu dois lire `PROJECT_RULES.md` ET `CHANGELOG_AI.md` en entier, puis me résumer en 2 à 3 lignes l'état actuel du projet.
2. Tu ne modifies que ce qui est demandé. Tu ne refactorises pas, ne renommes pas, ne supprimes pas et ne réorganises pas du code qui fonctionne sans que je te le demande.
3. Si une demande entre en conflit avec l'architecture ou une règle, tu me préviens AVANT de coder et tu attends ma validation.
4. Tu ne réécris jamais un fichier entier si une modification ciblée suffit.
5. Après chaque modification, tu vérifies que le projet compile (`flutter analyze`) et tu corriges les erreurs que tu as introduites.
6. APRÈS chaque modification, tu ajoutes une entrée dans `CHANGELOG_AI.md` (voir format ci-dessous). Une tâche n'est pas terminée tant que le journal n'est pas à jour.
7. Si tu découvres un bug ou un problème hors du sujet demandé, tu le signales dans le journal (section "À traiter") au lieu de le corriger de ton propre chef.
8. À la fin de CHAQUE tâche, après avoir mis à jour `CHANGELOG_AI.md`, tu m'écris un "RAPPORT DE PASSATION" dans le chat, en suivant exactement le format défini dans la section "Format du rapport de passation". Une tâche n'est pas terminée sans ce rapport.

## Format de CHANGELOG_AI.md
Une entrée par modification, la plus récente en haut :

```markdown
## [Numéro] - Titre court
- Date :
- Demande : ce que j'ai demandé
- Fichiers créés :
- Fichiers modifiés :
- Fichiers supprimés :
- Packages ajoutés :
- Détail : ce qui a été fait et pourquoi
- État : fonctionne / à tester / problème connu
- À traiter : points à surveiller ou prochaines étapes
```

Termine le fichier par une section "Décisions importantes" listant les choix techniques que l'on ne doit pas remettre en cause sans demander.

## Format du rapport de passation
Ce rapport est destiné à être copié-collé tel quel à un autre assistant IA qui n'a pas accès au projet. Il doit donc être autonome, factuel et complet. Il doit tenir dans un seul bloc de code Markdown.

```text
RAPPORT DE PASSATION
1. Étape terminée : titre de la tâche et numéro de l'entrée du journal
2. Résumé : 2 à 3 phrases sur ce qui a été fait
3. État global du projet :
   - Fonctionnalités terminées et testées
   - Fonctionnalités terminées mais non testées
   - Fonctionnalités en cours ou cassées
4. Arborescence actuelle : liste des fichiers du dossier lib/ avec une ligne d'explication par fichier
5. Packages installés (nom + version + utilité)
6. Décisions techniques importantes en vigueur
7. Problèmes connus, erreurs rencontrées et warnings
8. Résultat de `flutter analyze` (propre ou liste des erreurs)
9. Comment tester : commandes et actions à effectuer pour vérifier cette étape
10. Prochaine étape suggérée
```


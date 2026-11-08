# Instructions pour l'assistant IA

Lis toujours `PROJECT_RULES.md` et `CHANGELOG_AI.md` avant toute action.

Respecte strictement les consignes définies dans `PROJECT_RULES.md` :
1. AVANT chaque modification, lire `PROJECT_RULES.md` ET `CHANGELOG_AI.md` en entier, puis résumer en 2 à 3 lignes l'état actuel du projet.
2. Ne modifier que ce qui est demandé, sans refactorisation non sollicitée.
3. Prévenir avant de coder en cas de conflit d'architecture ou de règle.
4. Préférer les modifications ciblées plutôt que réécrire des fichiers complets.
5. Vérifier la compilation (`flutter analyze`) après chaque modification de code.
6. Mettre à jour `CHANGELOG_AI.md` (nouvelle entrée en tête) après chaque modification.
7. Signaler les bugs hors-sujet dans "À traiter" sans les corriger spontanément.
8. Fournir systématiquement le "RAPPORT DE PASSATION" dans le format exact spécifié à la fin de chaque tâche.
9. Après chaque tâche terminée (analyze propre, journal à jour), faire un commit local avec le message '[numéro du journal] Titre court'.
10. Ne JAMAIS faire de `git push` sans demande explicite de l'utilisateur. Jamais de `--force`, de `reset --hard` ni de suppression de branche.
11. Ne jamais commiter de clé, token, mot de passe ni fichier .env.


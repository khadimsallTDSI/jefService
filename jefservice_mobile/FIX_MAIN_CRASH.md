# Correctif Flutter — main.dart et écrans

## Problème identifié

Dans `lib/main.dart`, la carte technicien (bouton « Demander ») avait des parenthèses mal fermées autour des `SizedBox`, `ElevatedButton`, `Row` et `Padding`. Ce problème provoque une erreur d'analyse du fichier Dart.

## Correctifs

- Fermeture correcte des widgets sur la carte technicien.
- Plus de `!` sur l'identifiant du service lors de la recherche des professionnels ou de la création de la mission ; les identifiants manquants génèrent un message géré par l'interface.
- Le tableau de bord professionnel affiche une erreur si le profil n'existe pas au lieu d'attendre indéfiniment.
- Le rafraîchissement des missions laisse `FutureBuilder` gérer les erreurs d'API sans produire une erreur asynchrone non interceptée.
- La requête de missions applique correctement un filtre conditionnel JHipster parenthésé (`clientId.equals` / `technicienId.equals`).
- Lorsque la restauration d'une session échoue à cause du réseau ou d'une configuration manquante, un écran de récupération propose « Réessayer » et « Changer de compte ».
- Cinq tests d'écrans supplémentaires sous `test/screens_test.dart`.

## Commandes de contrôle (à exécuter sur ton Mac)

```bash
cd jefservice_mobile
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://ADRESSE_REELLE_DE_L_API
```

Si une erreur subsiste, partager la première erreur de `flutter analyze` et le journal Flutter complet autour du plantage. Les messages sur le parcours OTP technicien ou l'autorisation d'accès aux ressources nécessitent une vérification côté backend avec Khadim, sans changement serveur dans ce commit.

**Tous les fichiers de ce correctif restent strictement dans `jefservice_mobile/`.**

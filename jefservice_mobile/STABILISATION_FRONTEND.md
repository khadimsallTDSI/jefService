# Stabilisation mobile — 11 octobre 2026

## Correctifs sur `develop`

- Navigation Flutter : initialisation différée des onglets pour ne charger que les écrans visités.
- Tableau de bord technicien : états de chargement, erreur et profil absent distincts ; plus de chargement sans fin.
- Sélecteur de documents : vérification du fichier et traitement des erreurs de sélection natives.
- Profil utilisateur : les contrôleurs des champs appartiennent désormais à une fenêtre avec cycle de vie indépendant, pour éviter les accès après `dispose`.
- Authentification : segmentation adaptée aux petits écrans et possibilité de demander un nouveau SMS après 45 secondes (temporisation locale ; les limites serveur restent prioritaires).
- Android : connexions HTTP locales autorisées **uniquement en debug** dans `android/app/src/debug/AndroidManifest.xml`. L'application release exige toujours HTTPS dans `JefApi`.
- Tests Flutter ajoutés pour la navigation paresseuse, les états du tableau de bord et la fermeture du formulaire de profil.

## Contrôles à exécuter sur un poste disposant du SDK Flutter

```bash
git checkout develop
git pull --ff-only origin develop
cd jefservice_mobile
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` concerne l'émulateur Android avec Spring Boot démarré sur la machine hôte. Pour un téléphone physique, utiliser une URL joignable depuis le réseau du téléphone et privilégier HTTPS. Ne jamais utiliser la configuration HTTP de debug pour un build destiné aux utilisateurs.

**Limite de validation :** le SDK Flutter n'est pas accessible dans l'environnement de cette intervention ; la compilation et les tests doivent encore être exécutés localement avant publication.

**Périmètre :** tous les changements restent strictement sous `jefservice_mobile/`. Backend Spring Boot/Angular inchangé.

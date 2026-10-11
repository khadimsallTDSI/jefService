# Jef Service Mobile

Application Flutter pour les clients et les techniciens, dans le dépôt `Papathiam/jefService`.

## Technologies et interfaces

- Flutter / Material 3
- Palette : `#079B8F`, `#FF8500`, `#DFF7F4`, `#046B64`
- Connexion par numéro et OTP (4 chiffres), rôles client/technicien
- Catalogue des services, professionnels validés et disponibles, demande d'intervention
- Missions : lecture et transitions du côté professionnel
- Disponibilité du technicien, documents (CNI et diplôme), profil utilisateur
- Token JWT conservé dans `flutter_secure_storage`

## Démarrage sur Mac

```bash
cd jefservice_mobile
flutter pub get
flutter analyze
flutter test

# Pour générer iOS si nécessaire, sur macOS avec Xcode :
flutter create --platforms=ios --project-name=jefservice_mobile --org=com.jef.sn .
cd ios && pod install && cd ..

# Exécuter avec l'URL réelle du serveur backend
flutter run --dart-define=API_BASE_URL=https://api-votre-domaine.example
```

Sur Android Emulator : si Spring Boot tourne sur le Mac, utiliser `http://10.0.2.2:8080` en mode **debug** uniquement ; Android doit autoriser cleartext **uniquement en debug**. Un appareil physique doit joindre une IP ou un domaine accessible. En **Release**, l'application exige HTTPS.

## API utilisées

- `POST /api/register-client` (demande OTP client, et phase 1 de l'inscription technicien)
- `POST /api/validate-otp` (client)
- `POST /api/login-otp-request`, `POST /api/login-otp-validate` (technicien existant)
- `POST /api/technicien/validate-otp` (inscription technicien)
- `GET/POST /api/account`
- `GET /api/clients?userId.equals=...`
- `GET/PATCH /api/techniciens`
- `GET /api/service-jefs`
- `GET/POST/PATCH /api/missions`
- `GET /api/documents`, `POST /api/technicien/{id}/documents` (multipart `cni`, `DIPLOME`)

Les écrans ne simulent ni chat, ni paiement en ligne, ni notification push ; les API correspondantes n'ont pas été confirmées.

## Points bloquants backend identifiés, sans modification

1. La règle publique Spring Security pour `/api/technicien/validate-otp` manque un slash initial dans le contrôleur de sécurité analysé. Le flux professionnel pourrait produire HTTP 401/403. À confirmer avec Khadim.
2. Les endpoints CRUD JHipster, y compris missions, profils et documents, doivent vérifier côté serveur qu'un utilisateur ne peut agir que sur ses propres données. Les validations Flutter ne sont **pas** une sécurité suffisante.
3. L'endpoint `/api/technicien/{id}/documents` accepte les champs `cni` et `DIPLOME`, avec JWT.
4. Le projet initial ne contient pas les sources iOS sous git ; `flutter create --platforms=ios .` est nécessaire sur macOS.
5. `pubspec.lock` doit être régénéré sur une machine avec Flutter et inclus dans un prochain commit après vérification.

## Contrôles avant production

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://api-votre-domaine.example
flutter build appbundle --release --dart-define=API_BASE_URL=https://api-votre-domaine.example
```

Configurer la signature Android Release : le projet Flutter initial utilisait encore la signature de debug. Tester les permissions GPS, les OTP réels et chaque réponse du serveur de recette avant publication.

**Backend Spring Boot / Angular inchangé** : tous les fichiers de cette livraison sont sous `jefservice_mobile/`.

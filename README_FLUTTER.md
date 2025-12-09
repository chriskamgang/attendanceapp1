# 📱 Attendance App - Application Mobile Flutter

Application mobile de pointage par géolocalisation pour universités multi-campus.

---

## ✅ Ce qui a été implémenté

### 🏗️ Architecture

```
lib/
├── models/              # Modèles de données
│   ├── user.dart
│   ├── role.dart
│   ├── department.dart
│   ├── campus.dart
│   ├── attendance.dart
│   └── presence_check.dart
│
├── services/            # Services
│   ├── api_service.dart      # Communication avec Laravel API
│   ├── storage_service.dart  # Stockage local (SharedPreferences)
│   └── location_service.dart # Géolocalisation (Geolocator)
│
├── providers/           # State Management (Provider)
│   ├── auth_provider.dart
│   └── attendance_provider.dart
│
├── screens/             # Écrans
│   ├── auth/
│   │   └── login_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   └── attendance/
│       └── check_in_screen.dart
│
├── utils/               # Utilitaires
│   └── constants.dart   # URLs API et constantes
│
└── main.dart            # Point d'entrée
```

---

## 🎯 Fonctionnalités

### ✅ Authentification
- [x] Login avec email et mot de passe
- [x] Sauvegarde automatique du token
- [x] Vérification de session au démarrage
- [x] Logout

### ✅ Dashboard
- [x] Affichage des informations utilisateur
- [x] Statut check-in actif/inactif
- [x] Vérifications de présence en attente
- [x] Statistiques du mois (check-ins, retards, jours travaillés)
- [x] Liste des campus assignés

### ✅ Check-in / Check-out
- [x] Obtention de la position GPS
- [x] Calcul de distance avec le campus
- [x] Vérification de zone (dans/hors rayon)
- [x] Check-in avec validation de zone
- [x] Check-out avec calcul de durée
- [x] Affichage de la précision GPS
- [x] Rafraîchissement de position

### ✅ Géolocalisation
- [x] Demande de permissions
- [x] Obtention de position actuelle
- [x] Calcul de distance (formule de Haversine)
- [x] Vérification si dans une zone

---

## 📦 Dépendances

```yaml
dependencies:
  # HTTP & API
  http: ^1.2.0
  dio: ^5.4.0

  # State Management
  provider: ^6.1.1

  # Storage
  shared_preferences: ^2.2.2

  # Geolocation
  geolocator: ^11.0.0
  permission_handler: ^11.2.0

  # Google Maps
  google_maps_flutter: ^2.5.3

  # Firebase (notifications)
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10

  # Utils
  intl: ^0.19.0
  flutter_local_notifications: ^16.3.0
  image_picker: ^1.0.7
  cached_network_image: ^3.3.1

  # UI
  flutter_spinkit: ^5.2.0
  fluttertoast: ^8.2.4
```

---

## 🚀 Installation et Configuration

### 1. Configuration de l'API

Ouvrir `lib/utils/constants.dart` et configurer l'URL de l'API :

```dart
class ApiConstants {
  // Pour Android Emulator
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Pour iOS Simulator
  // static const String baseUrl = 'http://localhost:8000/api';

  // Pour vrai appareil (remplacer par votre IP locale)
  // static const String baseUrl = 'http://192.168.X.X:8000/api';
}
```

### 2. Permissions Android

Le fichier `android/app/src/main/AndroidManifest.xml` doit contenir :

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### 3. Permissions iOS

Le fichier `ios/Runner/Info.plist` doit contenir :

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Cette application a besoin de votre localisation pour le pointage</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Cette application a besoin de votre localisation en arrière-plan</string>
```

### 4. Installation des dépendances

```bash
cd attendance_app
flutter pub get
```

### 5. Lancer l'application

```bash
# Pour Android
flutter run

# Pour iOS
flutter run
```

---

## 🔑 Identifiants de Test

**Email**: admin@university.ga
**Mot de passe**: password123

---

## 📱 Écrans Disponibles

### 1. Splash Screen
- Vérification automatique de la session
- Redirection vers Login ou Home

### 2. Login Screen
- Formulaire de connexion
- Validation des champs
- Affichage des identifiants de test

### 3. Home Screen (Dashboard)
- En-tête utilisateur avec photo et rôle
- Statut check-in actif/inactif
- Alertes pour vérifications en attente
- Statistiques du mois
- Liste des campus avec navigation

### 4. Check-in Screen
- Informations du campus sélectionné
- Position GPS actuelle
- Distance du campus
- Indicateur dans/hors zone
- Bouton check-in (vert) ou check-out (rouge)

---

## 🔄 Flux d'Utilisation

1. **Lancement de l'app** → Splash Screen vérifie l'authentification
2. **Si non connecté** → Login Screen
3. **Si connecté** → Home Screen (Dashboard)
4. **Sélection d'un campus** → Check-in Screen
5. **Vérification de zone** → Si OK, check-in possible
6. **Check-in effectué** → Retour au Dashboard
7. **Pour sortir** → Retour sur le campus, check-out

---

## 🐛 Débogage

### Problème: API ne répond pas

1. Vérifier que Laravel tourne : `php artisan serve`
2. Vérifier l'URL dans `constants.dart`
3. Pour Android Emulator, utiliser `10.0.2.2` au lieu de `localhost`

### Problème: Permissions GPS refusées

1. Aller dans Paramètres de l'appareil
2. Applications → Attendance App → Permissions
3. Activer la localisation

### Problème: Erreur de compilation

```bash
flutter clean
flutter pub get
flutter run
```

---

## 📈 Prochaines Étapes

### À implémenter

- [ ] Écran historique des pointages
- [ ] Écran profil utilisateur
- [ ] Réponse aux vérifications de présence
- [ ] Notifications push (FCM)
- [ ] Carte Google Maps avec position
- [ ] Mode sombre
- [ ] Support multilingue (FR/EN)
- [ ] Tests unitaires

---

## 🛠️ Technologies Utilisées

- **Flutter 3.35.4**
- **Dart 3.9.2**
- **Provider** (state management)
- **Geolocator** (géolocalisation)
- **SharedPreferences** (stockage local)
- **HTTP/Dio** (communication API)

---

## 📝 Notes Importantes

### URLs API selon l'environnement

| Environnement | URL à utiliser |
|---------------|----------------|
| Android Emulator | `http://10.0.2.2:8000/api` |
| iOS Simulator | `http://localhost:8000/api` |
| Vrai appareil | `http://VOTRE_IP_LOCAL:8000/api` |

### Trouver votre IP locale

**macOS/Linux:**
```bash
ifconfig | grep "inet "
```

**Windows:**
```cmd
ipconfig
```

Chercher l'adresse IPv4 (ex: 192.168.1.100)

---

## 🤝 Support

Pour toute question :
1. Consulter la documentation Flutter : https://flutter.dev/docs
2. Vérifier les logs : `flutter logs`
3. Tester les endpoints API avec Postman

---

**Développé pour** : Universités avec système de pointage multi-campus
**Stack** : Flutter + Laravel 12 + MySQL
**Version** : 1.0.0

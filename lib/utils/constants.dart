class ApiConstants {
  // CONFIGURATION - Changer selon l'environnement
  static const bool isLocal = false; // Mettre false pour production

  // Base URLs
  // Pour iOS Simulator: utilisez 127.0.0.1 ou localhost
  // Pour émulateur Android: utilisez 10.0.2.2 au lieu de localhost
  // Pour appareil physique: utilisez l'IP de votre machine (ex: 192.168.x.x)
  static const String localUrl = 'http://127.0.0.1:8003/api';
  static const String productionUrl = 'https://rh.iues-insambot.com/api';

  // URL active selon l'environnement
  static String get baseUrl => isLocal ? localUrl : productionUrl;

  // Endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';

  // Attendance
  static const String checkIn = '/attendance/check-in';
  static const String checkOut = '/attendance/check-out';
  static const String attendanceHistory = '/attendance/my-history';
  static const String attendanceToday = '/attendance/today';
  static const String attendanceStats = '/attendance/stats';
  static const String currentStatus = '/attendance/current-status';

  // Campus
  static const String campuses = '/campuses';
  static const String myCampuses = '/campuses/my-campuses';
  static const String checkZone = '/campuses/check-zone';
  static const String calculateDistance = '/campuses/calculate-distance';

  // Presence Check
  static const String pendingChecks = '/presence-check/pending';
  static const String respondCheck = '/presence-check/respond';
  static const String presenceHistory = '/presence-check/history';

  // User
  static const String profile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String changePassword = '/user/change-password';
  static const String updateFcmToken = '/user/update-fcm-token';
  static const String dashboard = '/user/dashboard';
  static const String notifications = '/user/notifications';

  // Emploi du temps
  static const String mySchedule = '/emploi-du-temps/mon-emploi';
  static const String todaySchedule = '/emploi-du-temps/aujourdhui';
  static const String uesAvailableNow = '/emploi-du-temps/ues-disponibles-maintenant';

  // Salary Advances
  static const String salaryAdvances = '/salary-advances';

  // Moratoriums
  static const String moratoriums = '/moratoriums';

  // Tasks
  static const String myTasks = '/tasks';

  // Wallet
  static const String wallet = '/wallet';
  static const String walletTransfer = '/wallet/transfer';
  static const String walletTransactions = '/wallet/transactions';

  // Mise à jour
  static const String checkUpdate = '/check-update';

  // Bus Transport
  static const String busRegister = '/bus/register';
  static const String busStatus = '/bus/status';
  static const String busDisconnect = '/bus/disconnect';
  static const String busPointsRamassage = '/bus/points-ramassage';
  static const String busLieux = '/bus/lieux';
  static const String busLignes = '/bus/lignes';
  static const String busParcours = '/bus/parcours';
  static const String busTarifs = '/bus/tarifs';
  static const String busEnLigne = '/bus/en-ligne';
  static const String busMonBus = '/bus/mon-bus';
  static const String busPointRamassage = '/bus/point-ramassage';
  static const String busMesTrajets = '/bus/mes-trajets';
  static const String busAbonnements = '/bus/abonnements';
  static const String busAbonnementActif = '/bus/abonnement-actif';
  static const String busQrPass = '/bus/qr-pass';
  static const String busNotifications = '/bus/notifications';
  static const String busNotificationsNonLues = '/bus/notifications/non-lues';
}

class AppConstants {
  static const String appName = 'Estuaire RH';
  static const String appVersion = '2.1.1';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Geolocation
  static const double defaultAccuracy = 100.0; // mètres
  static const int locationTimeoutSeconds = 30;
}

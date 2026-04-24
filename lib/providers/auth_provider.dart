import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';
import '../services/firebase_notification_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final DeviceService _deviceService = DeviceService();

  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  // Vérifier si l'utilisateur est déjà connecté
  Future<void> checkAuth() async {
    // Ne pas appeler notifyListeners() au début pour éviter setState pendant build
    _isLoading = true;

    try {
      bool hasToken = await _storageService.hasToken();
      if (hasToken) {
        User? savedUser = await _storageService.getUser();
        if (savedUser != null) {
          _user = savedUser;
          _isAuthenticated = true;
          // Renvoyer le token FCM au backend à chaque lancement
          FirebaseNotificationService().resendTokenToBackend();
        }
      }
    } catch (e) {
      print('Erreur checkAuth: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String password, {bool isStudent = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Obtenir les informations du device
      final deviceInfo = await _deviceService.getDeviceInfo();

      final result = await _apiService.login(
        email,
        password,
        deviceId: deviceInfo['device_id']!,
        deviceModel: deviceInfo['device_model'],
        deviceOs: deviceInfo['device_os'],
        isStudent: isStudent,
      );

      if (result['success']) {
        _user = User.fromJson(result['data']['user']);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        // Envoyer le token FCM au backend après login
        FirebaseNotificationService().resendTokenToBackend();
        return {'success': true};
      } else {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': result['message']};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    // Supprimer le token FCM côté serveur AVANT de supprimer le token d'auth
    try {
      await _apiService.removeFcmToken();
    } catch (e) {
      print('Erreur suppression FCM token: $e');
    }

    // Supprimer le token FCM côté Firebase
    try {
      await FirebaseNotificationService().unsubscribe();
    } catch (e) {
      print('Erreur unsubscribe Firebase: $e');
    }

    await _apiService.logout();
    _user = null;
    _isAuthenticated = false;

    _isLoading = false;
    notifyListeners();
  }

  // Mettre à jour l'utilisateur localement
  void setUser(User user) {
    _user = user;
    _isAuthenticated = true;
    notifyListeners();
  }

  // Rafraîchir les données utilisateur
  Future<void> refreshUser() async {
    try {
      final result = await _apiService.getUser();
      if (result['success']) {
        _user = result['user'];
        notifyListeners();
      }
    } catch (e) {
      print('Erreur refresh user: $e');
    }
  }
}

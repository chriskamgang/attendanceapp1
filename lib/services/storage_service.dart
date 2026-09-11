import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/user.dart';

class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Token
  Future<void> saveToken(String token) async {
    await init();
    await _prefs!.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    await init();
    return _prefs!.getString(AppConstants.tokenKey);
  }

  Future<bool> hasToken() async {
    String? token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // User
  Future<void> saveUser(Map<String, dynamic> userData) async {
    await init();
    await _prefs!.setString(AppConstants.userKey, json.encode(userData));
  }

  Future<User?> getUser() async {
    await init();
    String? userJson = _prefs!.getString(AppConstants.userKey);
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  // Clear all
  ///
  /// Efface les seules données d'Estuaire RH. L'application héberge aussi
  /// l'espace INSAM BUS, dont les clés portent le préfixe `bus_` : un
  /// `clear()` global déconnecterait cet espace au passage, alors que les
  /// deux sessions sont indépendantes.
  Future<void> clearAll() async {
    await init();

    final aEffacer = _prefs!
        .getKeys()
        .where((cle) => !cle.startsWith(_busPrefix))
        .toList();

    for (final cle in aEffacer) {
      await _prefs!.remove(cle);
    }
  }

  /// Préfixe réservé au module INSAM BUS (voir `lib/bus/`).
  static const String _busPrefix = 'bus_';

  // Clear token only
  Future<void> clearToken() async {
    await init();
    await _prefs!.remove(AppConstants.tokenKey);
  }
}

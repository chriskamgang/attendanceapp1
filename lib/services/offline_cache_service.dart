import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service de cache offline pour les donnees essentielles.
/// Quand l'app est en ligne, les donnees sont sauvegardees localement.
/// Quand l'app est hors-ligne, on sert les donnees du cache.
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  SharedPreferences? _prefs;

  // Cles de cache
  static const String _keyPrefix = 'offline_cache_';
  static const String keyCampuses = '${_keyPrefix}campuses';
  static const String keyDashboard = '${_keyPrefix}dashboard';
  static const String keyProfile = '${_keyPrefix}profile';
  static const String keyAttendanceToday = '${_keyPrefix}attendance_today';
  static const String keyAttendanceHistory = '${_keyPrefix}attendance_history';
  static const String keyLeaves = '${_keyPrefix}leaves';
  static const String keyLeaveBalances = '${_keyPrefix}leave_balances';
  static const String keyConversations = '${_keyPrefix}conversations';
  static const String keyCertificates = '${_keyPrefix}certificates';
  static const String keyNotifications = '${_keyPrefix}notifications';
  static const String keyTasks = '${_keyPrefix}tasks';
  static const String keyUes = '${_keyPrefix}ues';
  static const String keyBreakStatus = '${_keyPrefix}break_status';
  static const String keyScheduleToday = '${_keyPrefix}schedule_today';
  static const String keySalaryStatus = '${_keyPrefix}salary_status';

  Future<SharedPreferences> get _storage async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ========== GENERIC CACHE METHODS ==========

  /// Sauvegarder des donnees en cache
  Future<void> cache(String key, dynamic data) async {
    final prefs = await _storage;
    final cacheEntry = {
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(key, json.encode(cacheEntry));
  }

  /// Recuperer des donnees du cache
  /// Retourne null si pas de cache ou si expire (maxAge en heures, 0 = pas d'expiration)
  Future<dynamic> getCached(String key, {int maxAgeHours = 24}) async {
    final prefs = await _storage;
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final entry = json.decode(raw);
      if (maxAgeHours > 0) {
        final cachedAt = DateTime.parse(entry['cached_at']);
        if (DateTime.now().difference(cachedAt).inHours > maxAgeHours) {
          return null; // Cache expire
        }
      }
      return entry['data'];
    } catch (_) {
      return null;
    }
  }

  /// Verifier si un cache existe et n'est pas expire
  Future<bool> hasCached(String key, {int maxAgeHours = 24}) async {
    final data = await getCached(key, maxAgeHours: maxAgeHours);
    return data != null;
  }

  /// Supprimer un cache specifique
  Future<void> clearCache(String key) async {
    final prefs = await _storage;
    await prefs.remove(key);
  }

  /// Supprimer tous les caches offline
  Future<void> clearAllCaches() async {
    final prefs = await _storage;
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Obtenir l'age du cache en minutes
  Future<int?> getCacheAgeMinutes(String key) async {
    final prefs = await _storage;
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final entry = json.decode(raw);
      final cachedAt = DateTime.parse(entry['cached_at']);
      return DateTime.now().difference(cachedAt).inMinutes;
    } catch (_) {
      return null;
    }
  }

  /// Formater l'age du cache pour affichage
  Future<String> getCacheAgeLabel(String key) async {
    final minutes = await getCacheAgeMinutes(key);
    if (minutes == null) return 'Pas de cache';
    if (minutes < 1) return 'A l\'instant';
    if (minutes < 60) return 'Il y a $minutes min';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'Il y a ${hours}h';
    final days = hours ~/ 24;
    return 'Il y a ${days}j';
  }
}

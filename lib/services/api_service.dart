import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../models/user.dart';
import '../models/campus.dart';
import '../models/attendance.dart';
import '../models/presence_check.dart';
import '../models/unite_enseignement.dart';
import '../models/complaint.dart';
import '../models/academic_result.dart';
import 'storage_service.dart';
import 'offline_cache_service.dart';

class ApiService {
  final StorageService _storageService = StorageService();
  final OfflineCacheService _cache = OfflineCacheService();

  // Client HTTP qui accepte tous les certificats SSL (pour vieux Android)
  static final http.Client _client = _createHttpClient();

  static http.Client _createHttpClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  // Cache du token en mémoire pour éviter les lectures répétées du storage
  static String? _cachedToken;

  // Wrapper pour GET avec timeout de 15 secondes
  Future<http.Response> _get(Uri url, {required Map<String, String> headers}) {
    return _client.get(url, headers: headers).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('{"message": "Délai dépassé, vérifiez votre connexion"}', 408),
    );
  }

  // Wrapper pour POST avec timeout de 15 secondes
  Future<http.Response> _post(Uri url, {required Map<String, String> headers, String? body}) {
    return _client.post(url, headers: headers, body: body).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('{"message": "Délai dépassé, vérifiez votre connexion"}', 408),
    );
  }

  Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      // Utiliser le token en cache mémoire si disponible
      _cachedToken ??= await _storageService.getToken();
      if (_cachedToken != null) {
        headers['Authorization'] = 'Bearer $_cachedToken';
      }
    }

    return headers;
  }

  /// Invalider le cache du token (à appeler au login/logout)
  static void clearTokenCache() {
    _cachedToken = null;
  }

  // ========== USER PROFILE ==========

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/user/profile'),
        headers: await _getHeaders(includeAuth: true),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keyProfile, data['user']);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false};
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyProfile, maxAgeHours: 168);
      if (cached != null) {
        return {'success': true, 'user': Map<String, dynamic>.from(cached), 'fromCache': true};
      }
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('${ApiConstants.baseUrl}/user/profile'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(data),
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        await _storageService.saveUser(result['user']);
        return {'success': true, 'user': User.fromJson(result['user'])};
      } else {
        return {'success': false, 'message': result['message'] ?? 'Erreur'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    try {
      final token = await _storageService.getToken();
      final dio = dio_pkg.Dio();
      
      final formData = dio_pkg.FormData.fromMap({
        'photo': await dio_pkg.MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await dio.put(
        '${ApiConstants.baseUrl}/user/profile',
        data: formData,
        options: dio_pkg.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _storageService.saveUser(data['user']);
        return {'success': true, 'user': User.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': 'Erreur lors de l\'upload'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== ABSENCES & RETARDS ==========

  Future<Map<String, dynamic>> getAbsences({int? month, int? year}) async {
    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/justifications/absences?month=$m&year=$y'),
        headers: await _getHeaders(includeAuth: true),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'absences': data['absences'] ?? []};
      }
      return {'success': false, 'message': 'Erreur de chargement'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getTardiness({int? month, int? year}) async {
    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/justifications/tardiness?month=$m&year=$y'),
        headers: await _getHeaders(includeAuth: true),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'tardiness': data['tardiness'] ?? []};
      }
      return {'success': false, 'message': 'Erreur de chargement'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getAbsenceSummary({int? month, int? year}) async {
    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/justifications/summary?month=$m&year=$y'),
        headers: await _getHeaders(includeAuth: true),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'summary': data['summary']};
      }
      return {'success': false, 'message': 'Erreur de chargement'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyJustificationRequests() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/justifications/my-requests'),
        headers: await _getHeaders(includeAuth: true),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'requests': data['requests'] ?? []};
      }
      return {'success': false, 'message': 'Erreur de chargement'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> submitJustification({
    required String type,
    required String date,
    required String reason,
  }) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/justifications'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'type': type,
          'date': date,
          'reason': reason,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Erreur'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  // ========== CONGES (Leave Requests) ==========

  Future<Map<String, dynamic>> getLeaves({String? status}) async {
    try {
      String url = '${ApiConstants.baseUrl}/leaves';
      if (status != null) url += '?status=$status';
      final response = await _get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (status == null) {
          await _cache.cache(OfflineCacheService.keyLeaves, data['leaves'] ?? []);
        }
        return {'success': true, 'leaves': data['leaves'] ?? []};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      if (status == null) {
        final cached = await _cache.getCached(OfflineCacheService.keyLeaves, maxAgeHours: 48);
        if (cached != null) {
          return {'success': true, 'leaves': cached, 'fromCache': true};
        }
      }
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getLeaveBalances() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/leaves/balances'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keyLeaveBalances, data['balances'] ?? []);
        return {'success': true, 'balances': data['balances'] ?? []};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyLeaveBalances, maxAgeHours: 48);
      if (cached != null) {
        return {'success': true, 'balances': cached, 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> requestLeave({
    required String type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/leaves'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'type': type,
          'start_date': startDate,
          'end_date': endDate,
          'reason': reason,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> cancelLeave(int leaveId) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/leaves/$leaveId/cancel'),
        headers: await _getHeaders(includeAuth: true),
      );

      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  // ========== COMPLAINTS ==========

  Future<Map<String, dynamic>> getComplaints() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/complaints'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final complaints = (data['complaints'] as List)
            .map((c) => Complaint.fromJson(c))
            .toList();
        return {'success': true, 'complaints': complaints};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> createComplaint(String subject, String content) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/complaints'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'subject': subject,
          'content': content,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== ACADEMIC RESULTS ==========

  Future<Map<String, dynamic>> getAcademicResults() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/results'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['results'] as List)
            .map((r) => AcademicResult.fromJson(r))
            .toList();
        return {'success': true, 'results': results};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== UPDATE CHECK ==========

  Future<Map<String, dynamic>> checkUpdate(String platform) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.checkUpdate}?platform=$platform'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"success": false, "message": "Timeout"}', 408),
      );

      if (response.statusCode == 200) {
        return {'success': true, ...json.decode(response.body)};
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== AUTH ==========

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    required String deviceId,
    String? deviceModel,
    String? deviceOs,
    bool isStudent = false,
  }) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
          'password': password,
          'device_id': deviceId,
          'device_model': deviceModel,
          'device_os': deviceOs,
          'is_student': isStudent,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Sauvegarder le token
        await _storageService.saveToken(data['token']);
        // Sauvegarder l'utilisateur
        await _storageService.saveUser(data['user']);
        return {'success': true, 'data': data};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Erreur de connexion'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}'),
        headers: await _getHeaders(includeAuth: true),
      );

      // Supprimer les données locales même si la requête échoue
      await _storageService.clearAll();

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': true}; // On considère comme réussi car on a nettoyé local
      }
    } catch (e) {
      await _storageService.clearAll();
      return {'success': true};
    }
  }

  Future<Map<String, dynamic>> getUser() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.user}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storageService.saveUser(data['user']);
        return {'success': true, 'user': User.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== ATTENDANCE ==========

  Future<Map<String, dynamic>> checkIn({
    required int campusId,
    required double latitude,
    required double longitude,
    double? accuracy,
    int? uniteEnseignementId,
  }) async {
    try {
      final body = {
        'campus_id': campusId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      };

      // Ajouter l'UE si fournie (pour les vacataires)
      if (uniteEnseignementId != null) {
        body['unite_enseignement_id'] = uniteEnseignementId;
      }

      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.checkIn}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'attendance': Attendance.fromJson(data['attendance']),
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> checkOut({
    required int campusId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.checkOut}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'campus_id': campusId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'checkout': Attendance.fromJson(data['checkout']),
          'checkin': Attendance.fromJson(data['checkin']),
          'duration_minutes': data['duration_minutes'],
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== OFFLINE SYNC ==========

  Future<Map<String, dynamic>> offlineCheckIn({
    required int campusId,
    required double latitude,
    required double longitude,
    double? accuracy,
    int? uniteEnseignementId,
    required String offlineTimestamp,
  }) async {
    try {
      final body = {
        'campus_id': campusId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'offline_timestamp': offlineTimestamp,
        'is_offline': true,
        'type': 'check-in',
      };
      if (uniteEnseignementId != null) {
        body['unite_enseignement_id'] = uniteEnseignementId;
      }

      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/attendance/offline-sync'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> offlineCheckOut({
    required int campusId,
    required double latitude,
    required double longitude,
    double? accuracy,
    required String offlineTimestamp,
  }) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/attendance/offline-sync'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'campus_id': campusId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'offline_timestamp': offlineTimestamp,
          'is_offline': true,
          'type': 'check-out',
        }),
      );

      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getCurrentStatus() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.currentStatus}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'has_active_checkin': data['has_active_checkin'],
          'active_checkins': (data['active_checkins'] as List)
              .map((a) => Attendance.fromJson(a))
              .toList(),
        };
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getAttendanceToday() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceToday}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== CAMPUS ==========

  Future<Map<String, dynamic>> getMyCampuses() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myCampuses}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Cache les donnees brutes pour le mode offline
        await _cache.cache(OfflineCacheService.keyCampuses, data['campuses']);
        List<Campus> campuses = (data['campuses'] as List)
            .map((c) => Campus.fromJson(c))
            .toList();
        return {'success': true, 'campuses': campuses};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      // Mode offline: servir depuis le cache
      final cached = await _cache.getCached(OfflineCacheService.keyCampuses, maxAgeHours: 168);
      if (cached != null) {
        List<Campus> campuses = (cached as List)
            .map((c) => Campus.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        return {'success': true, 'campuses': campuses, 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Alias pour getMyCampuses (utilisé par le service de géofencing)
  Future<Map<String, dynamic>> getCampuses() async {
    return getMyCampuses();
  }

  Future<Map<String, dynamic>> checkZone({
    required double latitude,
    required double longitude,
    int? campusId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.checkZone}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
          if (campusId != null) 'campus_id': campusId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Erreur de vérification'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== PRESENCE CHECK ==========

  Future<Map<String, dynamic>> getPendingChecks() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.pendingChecks}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<PresenceCheck> checks = (data['pending_checks'] as List)
            .map((c) => PresenceCheck.fromJson(c))
            .toList();
        return {'success': true, 'checks': checks};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> respondToCheck({
    required int presenceCheckId,
    required String response,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final httpResponse = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.respondCheck}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'presence_check_id': presenceCheckId,
          'response': response,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      final data = json.decode(httpResponse.body);

      if (httpResponse.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'warning': data['warning'],
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== USER ==========

  /// Charge toutes les données de l'écran d'accueil en une seule requête
  Future<Map<String, dynamic>> getHomeData() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/user/home-data'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache('home_data', data['data']);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      final cached = await _cache.getCached('home_data', maxAgeHours: 24);
      if (cached != null) {
        return {'success': true, 'data': Map<String, dynamic>.from(cached), 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.dashboard}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keyDashboard, data);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyDashboard, maxAgeHours: 24);
      if (cached != null) {
        return {'success': true, 'data': Map<String, dynamic>.from(cached), 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> updateFcmToken(String fcmToken) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.updateFcmToken}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Erreur de mise à jour'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> removeFcmToken() async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/user/remove-fcm-token'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Erreur de suppression'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== SALARY STATUS ==========

  Future<Map<String, dynamic>> getSalaryStatus({int? month, int? year}) async {
    try {
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;

      final url = '${ApiConstants.baseUrl}/user/salary-status?month=$targetMonth&year=$targetYear';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keySalaryStatus, data['data']);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement du statut salarial (${response.statusCode})'};
      }
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keySalaryStatus, maxAgeHours: 72);
      if (cached != null) {
        return {'success': true, 'data': Map<String, dynamic>.from(cached), 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getManualDeductions({int? month, int? year}) async {
    try {
      String url = '${ApiConstants.baseUrl}/user/manual-deductions';

      if (month != null && year != null) {
        url += '?month=$month&year=$year';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'deductions': data['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement des déductions'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getLoans({String? status}) async {
    try {
      String url = '${ApiConstants.baseUrl}/user/loans';

      if (status != null) {
        url += '?status=$status';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'loans': data['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement des prêts'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== PRESENCE NOTIFICATIONS ==========

  /// Récupérer les incidents de présence en attente
  Future<Map<String, dynamic>> getPendingPresenceIncidents() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/presence-notifications/pending'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'message': 'Erreur chargement incidents'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Répondre à une vérification de présence
  Future<Map<String, dynamic>> respondToPresenceCheck({
    required int incidentId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/presence-notifications/respond'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'incident_id': incidentId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erreur lors de la réponse'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Historique des incidents de présence
  Future<Map<String, dynamic>> getPresenceIncidentHistory({int page = 1}) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/presence-notifications/history?page=$page'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': 'Erreur chargement historique'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Statistiques de présence
  Future<Map<String, dynamic>> getPresenceStats() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/presence-notifications/stats'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': 'Erreur chargement stats'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== HISTORY ==========

  /// Récupérer l'historique de mes présences
  Future<Map<String, dynamic>> getMyHistory() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceHistory}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache('history', data['attendances'] ?? []);
        return {
          'success': true,
          'attendances': data['attendances'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors du chargement de l\'historique (${response.statusCode})',
        };
      }
    } catch (e) {
      // Fallback sur le cache en cas d'erreur réseau
      final cached = await _cache.getCached('history', maxAgeHours: 24);
      if (cached != null) {
        return {'success': true, 'attendances': cached, 'fromCache': true};
      }
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  // ========== UNITÉS D'ENSEIGNEMENT (VACATAIRES) ==========

  /// Récupérer toutes les UE du vacataire (activées et non activées)
  Future<Map<String, dynamic>> getUnitesEnseignement() async {
    try {
      final url = '${ApiConstants.baseUrl}/unites-enseignement';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keyUes, data['data']);
        return {
          'success': data['success'] ?? true,
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erreur lors du chargement des UE',
        };
      }
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyUes, maxAgeHours: 48);
      if (cached != null) {
        return {'success': true, 'data': Map<String, dynamic>.from(cached), 'fromCache': true};
      }
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  /// Récupérer uniquement les UE activées avec heures restantes > 0
  /// (Pour la sélection lors du check-in)
  Future<Map<String, dynamic>> getUnitesEnseignementActives() async {
    try {
      final url = '${ApiConstants.baseUrl}/unites-enseignement/actives';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final unites = (data['data'] as List)
            .map((ue) => UniteEnseignement.fromJson(ue))
            .toList();
        return {
          'success': true,
          'unites': unites,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erreur lors du chargement des UE actives',
          'unites': <UniteEnseignement>[],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
        'unites': <UniteEnseignement>[],
      };
    }
  }

  /// Récupérer les détails d'une UE spécifique
  Future<Map<String, dynamic>> getUniteEnseignement(int id) async {
    try {
      final url = '${ApiConstants.baseUrl}/unites-enseignement/$id';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erreur lors du chargement de l\'UE',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  /// Récupérer les statistiques globales des UE
  Future<Map<String, dynamic>> getStatistiquesUE() async {
    try {
      final url = '${ApiConstants.baseUrl}/unites-enseignement/statistiques';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'stats': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erreur lors du chargement des statistiques',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  // ========== EMPLOI DU TEMPS ==========

  /// Récupérer mon emploi du temps complet de la semaine
  Future<Map<String, dynamic>> getMySchedule() async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.mySchedule}';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? {},
        };
      } else {
        return {'success': false, 'message': 'Erreur de chargement de l\'emploi du temps'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Récupérer les créneaux d'aujourd'hui
  Future<Map<String, dynamic>> getTodaySchedule() async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.todaySchedule}';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keyScheduleToday, data['data'] ?? []);
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? [],
        };
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyScheduleToday, maxAgeHours: 12);
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Récupérer les UE disponibles maintenant (dans le créneau horaire)
  Future<Map<String, dynamic>> getUesAvailableNow() async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.uesAvailableNow}';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final unites = (data['data'] as List).map((ue) {
          return UniteEnseignement.fromJson(ue);
        }).toList();
        return {
          'success': true,
          'unites': unites,
          'raw_data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur de chargement des UE disponibles',
          'unites': <UniteEnseignement>[],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
        'unites': <UniteEnseignement>[],
      };
    }
  }

  // ========== AVANCES SUR SALAIRE ==========

  Future<Map<String, dynamic>> getSalaryAdvances() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryAdvances}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> requestSalaryAdvance({
    required int amount,
    required String reason,
  }) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryAdvances}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'amount': amount,
          'reason': reason,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message'], 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  // ========== MORATORIUMS (POUR ÉTUDIANTS) ==========

  Future<Map<String, dynamic>> getMoratoriums() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.moratoriums}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return {'success': true, 'data': body['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement des moratoires'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> requestMoratorium(String reason) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.moratoriums}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'reason': reason}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur lors de la demande'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // ========== TACHES (Tasks) ==========

  Future<Map<String, dynamic>> getMyTasks() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myTasks}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.cache(OfflineCacheService.keyTasks, data['data'] ?? []);
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': 'Erreur de chargement des taches'};
      }
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyTasks, maxAgeHours: 24);
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getTaskDetail(int taskId) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myTasks}/$taskId'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> updateTaskStatus(int taskId, String status, {String? note, int? penaltyAmount}) async {
    try {
      final body = {
        'status': status,
        if (note != null) 'note': note,
        if (penaltyAmount != null) 'penalty_amount': penaltyAmount,
      };

      final headers = await _getHeaders(includeAuth: true);
      final response = await _client.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myTasks}/$taskId/status'),
        headers: headers,
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('{"message": "Delai depasse"}', 408),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'message': data['message']};
      } else {
        final data = json.decode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Erreur'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  // ========== PAUSE DÉJEUNER ==========

  /// Démarrer la pause
  Future<Map<String, dynamic>> startBreak({required double latitude, required double longitude}) async {
    try {
      final url = '${ApiConstants.baseUrl}/break/start';
      final token = await _storageService.getToken();
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  /// Terminer la pause
  Future<Map<String, dynamic>> endBreak({required double latitude, required double longitude}) async {
    try {
      final url = '${ApiConstants.baseUrl}/break/end';
      final token = await _storageService.getToken();
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  /// Statut de la pause
  Future<Map<String, dynamic>> getBreakStatus() async {
    try {
      final url = '${ApiConstants.baseUrl}/break/status';
      final token = await _storageService.getToken();
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final result = json.decode(response.body);
      if (result['success'] == true) {
        await _cache.cache(OfflineCacheService.keyBreakStatus, result['data']);
      }
      return result;
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyBreakStatus, maxAgeHours: 4);
      if (cached != null) {
        return {'success': true, 'data': Map<String, dynamic>.from(cached), 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== WALLET (PORTEFEUILLE) ==========

  Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.wallet}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': {
            'balance': data['wallet']?['balance'] ?? 0,
            'transactions': data['transactions'] ?? [],
          }
        };
      } else {
        return {'success': false, 'message': 'Erreur de chargement du portefeuille'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> walletTransfer(String phone, int amount, String method) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.walletTransfer}'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'phone': phone,
          'amount': amount,
          'method': method,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': data['message'], 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur lors du transfert'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getWalletTransactions(int page) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.walletTransactions}?page=$page'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Erreur de chargement des transactions'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur reseau: $e'};
    }
  }

  // ========== GÉOFENCING ==========

  /// Envoyer un événement d'entrée en zone géographique
  Future<Map<String, dynamic>> sendGeofenceEntry(int campusId) async {
    try {
      final url = '${ApiConstants.baseUrl}/geofencing/entry';

      final response = await _client.post(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'campus_id': campusId,
        }),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Notification envoyée',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erreur lors de l\'envoi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  /// Marquer une notification de géofencing comme cliquée
  Future<Map<String, dynamic>> markGeofenceClicked(int geofenceNotificationId) async {
    try {
      final url = '${ApiConstants.baseUrl}/geofencing/clicked';

      final response = await _client.post(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'geofence_notification_id': geofenceNotificationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Marqué comme cliqué',
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de la mise à jour',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  /// Marquer une notification de géofencing comme ignorée
  Future<Map<String, dynamic>> markGeofenceIgnored(int geofenceNotificationId) async {
    try {
      final url = '${ApiConstants.baseUrl}/geofencing/ignored';

      final response = await _client.post(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'geofence_notification_id': geofenceNotificationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Marqué comme ignoré',
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de la mise à jour',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  /// Obtenir le statut du géofencing (activé ou non)
  Future<Map<String, dynamic>> getGeofencingStatus() async {
    try {
      final url = '${ApiConstants.baseUrl}/geofencing/status';

      final response = await _client.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de la récupération du statut',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }

  // ========== ATTESTATIONS DE TRAVAIL ==========

  Future<Map<String, dynamic>> getCertificates() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/certificates'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        await _cache.cache(OfflineCacheService.keyCertificates, data['certificates'] ?? []);
      }
      return {'success': data['success'] == true, 'certificates': data['certificates'] ?? []};
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyCertificates, maxAgeHours: 48);
      if (cached != null) {
        return {'success': true, 'certificates': cached, 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> requestCertificate({required String type, String? purpose}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/certificates'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'type': type, 'purpose': purpose}),
      );
      final data = json.decode(response.body);
      return {'success': response.statusCode == 201, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<String?> downloadCertificate(int id) async {
    try {
      final token = await _storageService.getToken();
      final dioClient = dio_pkg.Dio();
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/attestation_$id.pdf';

      await dioClient.download(
        '${ApiConstants.baseUrl}/certificates/$id/download',
        filePath,
        options: dio_pkg.Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/pdf'}),
      );
      return filePath;
    } catch (e) {
      return null;
    }
  }

  // ========== HISTORIQUE FICHES DE PAIE ==========

  Future<Map<String, dynamic>> getPayslipHistory() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/user/payslip-history'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'history': data['history'] ?? [], 'is_vacataire': data['is_vacataire'] ?? false};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== MESSAGERIE INTERNE ==========

  Future<Map<String, dynamic>> getConversations() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/messaging/conversations'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        await _cache.cache(OfflineCacheService.keyConversations, data['conversations'] ?? []);
      }
      return {'success': data['success'] == true, 'conversations': data['conversations'] ?? []};
    } catch (e) {
      final cached = await _cache.getCached(OfflineCacheService.keyConversations, maxAgeHours: 24);
      if (cached != null) {
        return {'success': true, 'conversations': cached, 'fromCache': true};
      }
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getMessages(int conversationId) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/messaging/conversations/$conversationId/messages'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'messages': data['messages'] ?? [], 'conversation': data['conversation']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> sendMessage(int conversationId, String body) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/messaging/conversations/$conversationId/messages'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'body': body}),
      );
      final data = json.decode(response.body);
      return {'success': response.statusCode == 201, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> createConversation({required int recipientId, required String message}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/messaging/conversations'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'recipient_id': recipientId, 'message': message}),
      );
      final data = json.decode(response.body);
      return {'success': response.statusCode == 201, 'conversation_id': data['conversation_id'], 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getContacts() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/messaging/contacts'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'contacts': data['contacts'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== EVALUATIONS ANNUELLES ==========

  Future<Map<String, dynamic>> getEvaluations() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/evaluations'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'evaluations': data['evaluations'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getEvaluationDetail(int id) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/evaluations/$id'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'evaluation': data['evaluation'], 'criteria': data['criteria'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> submitSelfEvaluation(int id, {required List<Map<String, dynamic>> scores, String? comments}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/evaluations/$id/self-evaluate'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'scores': scores, 'comments': comments}),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== CNPS ==========

  Future<Map<String, dynamic>> getCnpsRecord() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/cnps/record'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'record': data['record']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getCnpsContributions({int? year}) async {
    try {
      final url = year != null
          ? '${ApiConstants.baseUrl}/cnps/contributions?year=$year'
          : '${ApiConstants.baseUrl}/cnps/contributions';
      final response = await _get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {
        'success': data['success'] == true,
        'year': data['year'],
        'contributions': data['contributions'] ?? [],
        'totals': data['totals'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== ORGANIGRAMME ==========

  Future<Map<String, dynamic>> getOrgChartDepartments() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/orgchart/departments'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'departments': data['departments'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getDepartmentMembers(int departmentId) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/orgchart/departments/$departmentId/members'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'department': data['department'], 'members': data['members'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyHierarchy() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/orgchart/my-hierarchy'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {
        'success': data['success'] == true,
        'me': data['me'],
        'manager': data['manager'],
        'subordinates': data['subordinates'] ?? [],
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== ONBOARDING ==========

  Future<Map<String, dynamic>> getOnboardingProcesses() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/onboarding'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'processes': data['processes'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getOnboardingDetail(int id) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/onboarding/$id'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'process': data['process'], 'tasks': data['tasks'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> completeOnboardingTask(int processId, int taskId, {String? notes}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/onboarding/$processId/tasks/$taskId/complete'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'notes': notes}),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'message': data['message'] ?? '', 'process_completed': data['process_completed'] ?? false};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== RECRUTEMENT ==========

  Future<Map<String, dynamic>> getJobPostings({String? departmentId, String? contractType}) async {
    try {
      var url = '${ApiConstants.baseUrl}/recruitment/postings';
      final params = <String>[];
      if (departmentId != null) params.add('department_id=$departmentId');
      if (contractType != null) params.add('contract_type=$contractType');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await _get(Uri.parse(url), headers: await _getHeaders(includeAuth: true));
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'postings': data['postings'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getJobPostingDetail(int id) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/recruitment/postings/$id'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'posting': data['posting']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> applyToJob(int postingId, {required String name, required String email, String? phone, String? coverLetter}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/recruitment/postings/$postingId/apply'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'candidate_name': name, 'candidate_email': email, 'candidate_phone': phone, 'cover_letter': coverLetter}),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true || response.statusCode == 201, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getRecruitmentPipeline(int postingId) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/recruitment/postings/$postingId/pipeline'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'posting': data['posting'], 'applications': data['applications'] ?? [], 'pipeline_stats': data['pipeline_stats'], 'total': data['total']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== FORMATION / E-LEARNING ==========

  Future<Map<String, dynamic>> getTrainingCatalog({String? category, String? type, String? level}) async {
    try {
      var url = '${ApiConstants.baseUrl}/training/catalog';
      final params = <String>[];
      if (category != null) params.add('category=$category');
      if (type != null) params.add('type=$type');
      if (level != null) params.add('level=$level');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await _get(Uri.parse(url), headers: await _getHeaders(includeAuth: true));
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'programs': data['programs'] ?? [], 'categories': data['categories'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyTrainingEnrollments() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/training/my-enrollments'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'enrollments': data['enrollments'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getTrainingProgramDetail(int id) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/training/programs/$id'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'program': data['program'], 'enrollment': data['enrollment'], 'materials': data['materials'] ?? [], 'sessions': data['sessions'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> enrollInTraining(int programId, {int? sessionId}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/training/programs/$programId/enroll'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'session_id': sessionId}),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true || response.statusCode == 201, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> completeTrainingMaterial(int programId, int materialId, {double? score}) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/training/programs/$programId/materials/$materialId/complete'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'score': score}),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'progress': data['progress'], 'program_completed': data['program_completed'] ?? false};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== ANALYTICS RH ==========

  Future<Map<String, dynamic>> getHrDashboard() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/analytics/dashboard'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'dashboard': data['dashboard']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getHrTrends({int months = 6}) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/analytics/trends?months=$months'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'trends': data['trends'] ?? []};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getDepartmentAnalytics(int departmentId) async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/analytics/department/$departmentId'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {'success': data['success'] == true, 'department': data['department'], 'stats': data['stats']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== TICKETS ==========

  Future<Map<String, dynamic>> getTickets() async {
    try {
      final response = await _get(
        Uri.parse('${ApiConstants.baseUrl}/tickets'),
        headers: await _getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200,
        'tickets': data['tickets'] ?? [],
        'services': data['services'] ?? {},
        'categories': data['categories'] ?? {},
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e', 'tickets': [], 'services': {}, 'categories': {}};
    }
  }

  Future<Map<String, dynamic>> createTicket({
    required String category,
    required String targetService,
    required String subject,
    required String description,
    String? attachmentPath,
  }) async {
    try {
      final token = await _storageService.getToken();
      final dio = dio_pkg.Dio();

      final formData = dio_pkg.FormData.fromMap({
        'category': category,
        'target_service': targetService,
        'subject': subject,
        'description': description,
        if (attachmentPath != null)
          'attachment': await dio_pkg.MultipartFile.fromFile(attachmentPath),
      });

      final response = await dio.post(
        '${ApiConstants.baseUrl}/tickets',
        data: formData,
        options: dio_pkg.Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return {
        'success': response.statusCode == 201,
        'message': response.data['message'] ?? '',
        'ticket': response.data['ticket'],
      };
    } catch (e) {
      if (e is dio_pkg.DioException && e.response != null) {
        final data = e.response!.data;
        return {'success': false, 'message': data['message'] ?? 'Erreur serveur'};
      }
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> addTicketComment(dynamic ticketId, String comment) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/tickets/$ticketId/comment'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'comment': comment}),
      );
      final data = json.decode(response.body);
      return {'success': response.statusCode == 201, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> rateTicket(dynamic ticketId, int rating) async {
    try {
      final response = await _post(
        Uri.parse('${ApiConstants.baseUrl}/tickets/$ticketId/rate'),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({'rating': rating}),
      );
      final data = json.decode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
}

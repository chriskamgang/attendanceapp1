import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/user.dart';
import '../models/campus.dart';
import '../models/attendance.dart';
import '../models/presence_check.dart';
import '../models/unite_enseignement.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storageService = StorageService();

  Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      String? token = await _storageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ========== UPDATE CHECK ==========

  Future<Map<String, dynamic>> checkUpdate(String platform) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.checkUpdate}?platform=$platform'),
        headers: {'Accept': 'application/json'},
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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
        headers: await _getHeaders(),
        body: json.encode({
          'email': email,
          'password': password,
          'device_id': deviceId,
          'device_model': deviceModel,
          'device_os': deviceOs,
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
      final response = await http.post(
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
      final response = await http.get(
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

      final response = await http.post(
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
      final response = await http.post(
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

  Future<Map<String, dynamic>> getCurrentStatus() async {
    try {
      final response = await http.get(
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
      final response = await http.get(
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
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myCampuses}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Campus> campuses = (data['campuses'] as List)
            .map((c) => Campus.fromJson(c))
            .toList();
        return {'success': true, 'campuses': campuses};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
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
      final response = await http.post(
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
      final response = await http.get(
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
      final httpResponse = await http.post(
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

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.dashboard}'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> updateFcmToken(String fcmToken) async {
    try {
      final response = await http.post(
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

  // ========== SALARY STATUS ==========

  Future<Map<String, dynamic>> getSalaryStatus({int? month, int? year}) async {
    try {
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;

      final url = '${ApiConstants.baseUrl}/user/salary-status?month=$targetMonth&year=$targetYear';
      print('💰 Fetching salary status from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        print('❌ Salary Status Error: ${response.statusCode}');
        return {'success': false, 'message': 'Erreur de chargement du statut salarial (${response.statusCode})'};
      }
    } catch (e) {
      print('💥 Exception getSalaryStatus: $e');
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  Future<Map<String, dynamic>> getManualDeductions({int? month, int? year}) async {
    try {
      String url = '${ApiConstants.baseUrl}/user/manual-deductions';

      if (month != null && year != null) {
        url += '?month=$month&year=$year';
      }

      final response = await http.get(
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

      final response = await http.get(
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
      final response = await http.get(
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
      final response = await http.post(
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
      final response = await http.get(
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
      final response = await http.get(
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
      final url = '${ApiConstants.baseUrl}${ApiConstants.attendanceHistory}';
      print('🔍 Fetching history from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'attendances': data['attendances'] ?? [],
        };
      } else {
        print('❌ Error: Status ${response.statusCode}, Body: ${response.body}');
        return {
          'success': false,
          'message': 'Erreur lors du chargement de l\'historique (${response.statusCode})',
        };
      }
    } catch (e) {
      print('💥 Exception: $e');
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
      print('🔍 Fetching UE from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📡 Response status: ${response.statusCode}');

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
          'message': errorData['message'] ?? 'Erreur lors du chargement des UE',
        };
      }
    } catch (e) {
      print('💥 Exception: $e');
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
      print('🔍 Fetching active UE from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📡 Response status: ${response.statusCode}');

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
      print('💥 Exception: $e');
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
      print('🔍 Fetching UE details from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📡 Response status: ${response.statusCode}');

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
      print('💥 Exception: $e');
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
      print('🔍 Fetching UE stats from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📡 Response status: ${response.statusCode}');

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
      print('💥 Exception: $e');
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

      final response = await http.get(
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

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? [],
        };
      } else {
        return {'success': false, 'message': 'Erreur de chargement'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Récupérer les UE disponibles maintenant (dans le créneau horaire)
  Future<Map<String, dynamic>> getUesAvailableNow() async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.uesAvailableNow}';

      final response = await http.get(
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

  // ========== PAUSE DÉJEUNER ==========

  /// Démarrer la pause
  Future<Map<String, dynamic>> startBreak({required double latitude, required double longitude}) async {
    try {
      final url = '${ApiConstants.baseUrl}/break/start';
      final token = await _storageService.getToken();
      final response = await http.post(
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
      final response = await http.post(
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
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== GÉOFENCING ==========

  /// Envoyer un événement d'entrée en zone géographique
  Future<Map<String, dynamic>> sendGeofenceEntry(int campusId) async {
    try {
      final url = '${ApiConstants.baseUrl}/geofencing/entry';
      print('📍 Sending geofence entry for campus: $campusId');

      final response = await http.post(
        Uri.parse(url),
        headers: await _getHeaders(includeAuth: true),
        body: json.encode({
          'campus_id': campusId,
        }),
      );

      print('📡 Response status: ${response.statusCode}');

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
      print('💥 Exception: $e');
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

      final response = await http.post(
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
      print('💥 Exception: $e');
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

      final response = await http.post(
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
      print('💥 Exception: $e');
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

      final response = await http.get(
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
      print('💥 Exception: $e');
      return {
        'success': false,
        'message': 'Erreur réseau: $e',
      };
    }
  }
}

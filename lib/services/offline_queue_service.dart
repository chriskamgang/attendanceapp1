import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'api_service.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Database? _database;
  final ApiService _apiService = ApiService();
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  // Stream pour notifier l'UI des changements
  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  final _onlineStatusController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_queue.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            campus_id INTEGER NOT NULL,
            campus_name TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            unite_enseignement_id INTEGER,
            timestamp TEXT NOT NULL,
            created_at TEXT NOT NULL,
            sync_status TEXT DEFAULT 'pending',
            sync_error TEXT,
            retry_count INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Initialiser le monitoring de connectivite
  Future<void> init() async {
    await database; // Ensure DB is ready

    // Verifier le statut initial
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    _onlineStatusController.add(_isOnline);

    // Ecouter les changements de connectivite
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      _onlineStatusController.add(_isOnline);
    });

    // Notifier le compte initial
    _notifyPendingCount();
  }

  /// Ajouter un check-in a la file d'attente offline
  Future<int> queueCheckIn({
    required int campusId,
    String? campusName,
    required double latitude,
    required double longitude,
    double? accuracy,
    int? uniteEnseignementId,
  }) async {
    final db = await database;
    final now = DateTime.now();

    final id = await db.insert('pending_actions', {
      'action_type': 'check-in',
      'campus_id': campusId,
      'campus_name': campusName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'unite_enseignement_id': uniteEnseignementId,
      'timestamp': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'sync_status': 'pending',
      'retry_count': 0,
    });

    _notifyPendingCount();
    return id;
  }

  /// Ajouter un check-out a la file d'attente offline
  Future<int> queueCheckOut({
    required int campusId,
    String? campusName,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final db = await database;
    final now = DateTime.now();

    final id = await db.insert('pending_actions', {
      'action_type': 'check-out',
      'campus_id': campusId,
      'campus_name': campusName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'sync_status': 'pending',
      'retry_count': 0,
    });

    _notifyPendingCount();
    return id;
  }

  /// Obtenir le nombre d'actions en attente
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_actions WHERE sync_status = 'pending'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Obtenir toutes les actions en attente
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    return await db.query(
      'pending_actions',
      where: "sync_status = 'pending'",
      orderBy: 'timestamp ASC',
    );
  }

  /// Synchroniser toutes les actions en attente
  Future<Map<String, dynamic>> syncPendingActions() async {
    if (_isSyncing || !_isOnline) {
      return {'success': false, 'message': 'Synchronisation impossible'};
    }

    _isSyncing = true;
    final db = await database;
    int synced = 0;
    int failed = 0;
    List<String> errors = [];

    try {
      final pending = await getPendingActions();

      for (final action in pending) {
        try {
          final result = await _syncAction(action);

          if (result['success'] == true) {
            await db.update(
              'pending_actions',
              {'sync_status': 'synced'},
              where: 'id = ?',
              whereArgs: [action['id']],
            );
            synced++;
          } else {
            final retryCount = (action['retry_count'] as int) + 1;
            final errorMsg = result['message'] ?? 'Erreur inconnue';

            // Apres 5 tentatives, marquer comme echoue
            if (retryCount >= 5) {
              await db.update(
                'pending_actions',
                {
                  'sync_status': 'failed',
                  'sync_error': errorMsg,
                  'retry_count': retryCount,
                },
                where: 'id = ?',
                whereArgs: [action['id']],
              );
              failed++;
              errors.add(errorMsg);
            } else {
              await db.update(
                'pending_actions',
                {
                  'sync_error': errorMsg,
                  'retry_count': retryCount,
                },
                where: 'id = ?',
                whereArgs: [action['id']],
              );
              failed++;
            }
          }
        } catch (e) {
          failed++;
          errors.add(e.toString());
        }
      }
    } finally {
      _isSyncing = false;
      _notifyPendingCount();
    }

    return {
      'success': true,
      'synced': synced,
      'failed': failed,
      'errors': errors,
    };
  }

  /// Synchroniser une action individuelle via l'API
  Future<Map<String, dynamic>> _syncAction(Map<String, dynamic> action) async {
    final type = action['action_type'] as String;
    final offlineTimestamp = action['timestamp'] as String;

    if (type == 'check-in') {
      return await _apiService.offlineCheckIn(
        campusId: action['campus_id'] as int,
        latitude: action['latitude'] as double,
        longitude: action['longitude'] as double,
        accuracy: action['accuracy'] as double?,
        uniteEnseignementId: action['unite_enseignement_id'] as int?,
        offlineTimestamp: offlineTimestamp,
      );
    } else {
      return await _apiService.offlineCheckOut(
        campusId: action['campus_id'] as int,
        latitude: action['latitude'] as double,
        longitude: action['longitude'] as double,
        accuracy: action['accuracy'] as double?,
        offlineTimestamp: offlineTimestamp,
      );
    }
  }

  /// Supprimer les actions synchronisees de plus de 7 jours
  Future<void> cleanupOldActions() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await db.delete(
      'pending_actions',
      where: "sync_status = 'synced' AND created_at < ?",
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// Supprimer une action echouee
  Future<void> deleteFailedAction(int id) async {
    final db = await database;
    await db.delete(
      'pending_actions',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyPendingCount();
  }

  void _notifyPendingCount() async {
    final count = await getPendingCount();
    _pendingCountController.add(count);
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
    _onlineStatusController.close();
  }
}

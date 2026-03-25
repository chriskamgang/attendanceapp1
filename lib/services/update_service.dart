import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'api_service.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final ApiService _apiService = ApiService();

  /// Compare deux versions (ex: "2.0.0" > "1.0.0")
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }

  /// Vérifier si une mise à jour est disponible
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final result = await _apiService.checkUpdate(platform);

      if (result['success'] != true) return;

      final String currentVersion = AppConstants.appVersion;
      final String minVersion = result['min_version'] ?? currentVersion;
      final String latestVersion = result['latest_version'] ?? currentVersion;
      final String downloadUrl = result['download_url'] ?? '';
      final String releaseNotes = result['release_notes'] ?? '';

      // Mise à jour obligatoire
      if (_compareVersions(currentVersion, minVersion) < 0) {
        if (context.mounted) {
          _showForceUpdateDialog(context, latestVersion, releaseNotes, downloadUrl);
        }
        return;
      }

      // Mise à jour optionnelle
      if (_compareVersions(currentVersion, latestVersion) < 0) {
        if (context.mounted) {
          _showOptionalUpdateDialog(context, latestVersion, releaseNotes, downloadUrl);
        }
      }
    } catch (e) {
      print('Erreur vérification mise à jour: $e');
    }
  }

  /// Dialogue de mise à jour OBLIGATOIRE (non dismissible)
  void _showForceUpdateDialog(BuildContext context, String version, String notes, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('Mise à jour requise', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Une nouvelle version ($version) est disponible. Cette mise à jour est obligatoire pour continuer à utiliser l\'application.',
                style: const TextStyle(fontSize: 14),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Nouveautés :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(notes, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
              const SizedBox(height: 12),
              Text(
                'Version actuelle : ${AppConstants.appVersion}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadAndInstall(context, url),
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Télécharger la mise à jour', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogue de mise à jour OPTIONNELLE
  void _showOptionalUpdateDialog(BuildContext context, String version, String notes, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Mise à jour disponible', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La version $version est disponible.',
              style: const TextStyle(fontSize: 14),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Nouveautés :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(notes, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstall(context, url);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  /// Télécharger et installer l'APK (Android) ou ouvrir le lien (iOS)
  Future<void> _downloadAndInstall(BuildContext context, String url) async {
    if (url.isEmpty) return;

    if (Platform.isIOS) {
      // Pour iOS, on ne peut pas installer directement — ouvrir le lien
      // TODO: Ouvrir l'URL App Store/TestFlight
      return;
    }

    // Android — télécharger l'APK et l'installer
    _showDownloadProgress(context);

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/insam-presence-update.apk';
      final file = File(filePath);

      final response = await http.get(Uri.parse(url));
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Fermer le dialogue de progression
      }

      // Ouvrir l'APK pour installation
      await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dialogue de progression du téléchargement
  void _showDownloadProgress(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Téléchargement en cours...', style: TextStyle(fontSize: 14)),
              SizedBox(height: 4),
              Text('Veuillez patienter', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

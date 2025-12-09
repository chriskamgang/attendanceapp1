import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/security_service.dart';
import '../services/security_api_service.dart';
import '../services/secure_checkin_service.dart';

/// Écran de test pour le système de sécurité anti-fraude
/// Permet de tester toutes les détections de violations
class SecurityTestScreen extends StatefulWidget {
  const SecurityTestScreen({Key? key}) : super(key: key);

  @override
  State<SecurityTestScreen> createState() => _SecurityTestScreenState();
}

class _SecurityTestScreenState extends State<SecurityTestScreen> {
  final SecurityService _securityService = SecurityService();
  final SecurityApiService _securityApi = SecurityApiService();
  final SecureCheckinService _secureCheckin = SecureCheckinService();

  SecurityCheckResult? _lastCheckResult;
  bool _isChecking = false;
  String _statusMessage = 'Prêt pour test';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Sécurité Anti-Fraude'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête avec icône
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.security, size: 64, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    Text(
                      'Système Anti-Fraude',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Testez la détection de: VPN, Fake GPS, Root, Émulateurs',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Statut actuel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(), width: 2),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(), color: _getStatusColor(), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statut:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton de test principal
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _runSecurityCheck,
              icon: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isChecking ? 'Vérification en cours...' : 'Lancer Test Sécurité'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // Bouton test check-in complet
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _testSecureCheckin,
              icon: const Icon(Icons.login),
              label: const Text('Test Check-In Sécurisé Complet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 24),

            // Résultats des tests
            if (_lastCheckResult != null) ...[
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Résultats de la Vérification',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Carte récapitulatif
              Card(
                color: _lastCheckResult!.hasViolations
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _lastCheckResult!.hasViolations
                                ? Icons.error
                                : Icons.check_circle,
                            color: _lastCheckResult!.hasViolations
                                ? Colors.red
                                : Colors.green,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastCheckResult!.hasViolations
                                      ? 'VIOLATIONS DÉTECTÉES'
                                      : 'AUCUNE VIOLATION',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _lastCheckResult!.hasViolations
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'Sévérité: ${_lastCheckResult!.getSeverity().toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_lastCheckResult!.hasViolations) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Types: ${_lastCheckResult!.getViolationTypesFormatted()}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Détails des vérifications
              _buildCheckItem('VPN Détecté', _lastCheckResult!.violations['vpn']),
              _buildCheckItem('Fake GPS', _lastCheckResult!.violations['mock']),
              _buildCheckItem('Root/Jailbreak', _lastCheckResult!.violations['root']),
              _buildCheckItem('Émulateur', _lastCheckResult!.violations['emulator']),
              _buildCheckItem('GPS Incohérent', _lastCheckResult!.violations['gps_inconsistent']),

              const SizedBox(height: 24),

              // Informations appareil
              ExpansionTile(
                title: const Text('Informations Appareil'),
                leading: const Icon(Icons.phone_android),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _lastCheckResult!.deviceInfo.entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${e.key}: ${e.value}',
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Instructions de Test',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('1. Activez un VPN pour tester la détection VPN'),
                    const Text('2. Utilisez Fake GPS pour tester la détection Mock Location'),
                    const Text('3. Testez sur un appareil rooté/jailbreaké si possible'),
                    const Text('4. Testez sur un émulateur Android'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool? detected) {
    final isDetected = detected == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isDetected ? Icons.warning : Icons.check_circle,
          color: isDetected ? Colors.red : Colors.green,
        ),
        title: Text(label),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDetected ? Colors.red.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isDetected ? 'DÉTECTÉ' : 'OK',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDetected ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_lastCheckResult == null) return Colors.grey;
    return _lastCheckResult!.hasViolations ? Colors.red : Colors.green;
  }

  IconData _getStatusIcon() {
    if (_lastCheckResult == null) return Icons.help_outline;
    return _lastCheckResult!.hasViolations ? Icons.error : Icons.check_circle;
  }

  Future<void> _runSecurityCheck() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Vérification en cours...';
    });

    try {
      // Obtenir la position actuelle
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('Impossible d\'obtenir la position: $e');
      }

      // Effectuer la vérification
      final result = await _securityService.performSecurityCheck(
        currentPosition: position,
        previousPosition: null,
      );

      setState(() {
        _lastCheckResult = result;
        _statusMessage = result.hasViolations
            ? 'Violations détectées!'
            : 'Aucune violation - Tout est OK';
      });

      // Afficher snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.hasViolations
                ? '⚠️ ${result.getViolationTypesFormatted()} détecté(s)'
                : '✅ Vérification réussie - Aucune violation'),
            backgroundColor: result.hasViolations ? Colors.red : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _testSecureCheckin() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Test check-in sécurisé...';
    });

    try {
      // Obtenir la position actuelle
      final position = await Geolocator.getCurrentPosition();

      // Effectuer check-in sécurisé (avec user ID fictif pour test)
      final result = await _secureCheckin.performSecureCheckIn(
        userId: 1, // ID de test
        campusId: 1, // ID de test
        currentPosition: position,
        authToken: 'test_token', // Token de test
      );

      setState(() {
        _lastCheckResult = result.securityCheck;
        _statusMessage = result.message;
      });

      // Afficher dialogue avec résultat
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(result.success ? 'Check-In Réussi' : 'Check-In Bloqué'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message),
                if (result.blocked) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Raison: ${result.blockReason}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _securityService.dispose();
    _secureCheckin.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ecran de divulgation obligatoire (Google Play policy)
/// Doit s'afficher AVANT de demander ACCESS_BACKGROUND_LOCATION
class LocationDisclosureScreen extends StatelessWidget {
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const LocationDisclosureScreen({
    super.key,
    required this.onAccepted,
    required this.onDeclined,
  });

  static const String _consentKey = 'location_disclosure_accepted';

  /// Verifie si l'utilisateur a deja accepte la divulgation
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  /// Sauvegarde le consentement
  static Future<void> _saveConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
  }

  /// Verifie si la permission "always" est necessaire
  static Future<bool> needsBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission != LocationPermission.always;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Icone
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  size: 50,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Titre
              Text(
                'Accès à votre localisation',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Explication principale
              Text(
                'Cette application utilise votre position GPS, y compris en arrière-plan, pour les fonctionnalités suivantes :',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Raisons detaillees
              _buildReason(
                Icons.check_circle_outline,
                'Pointage de présence',
                'Vérifier que vous êtes bien sur le campus lors de vos pointages d\'entrée et de sortie.',
              ),
              const SizedBox(height: 12),
              _buildReason(
                Icons.notifications_active_outlined,
                'Notification automatique',
                'Vous prévenir automatiquement quand vous arrivez à proximité d\'un campus pour faciliter le pointage.',
              ),
              const SizedBox(height: 12),
              _buildReason(
                Icons.verified_user_outlined,
                'Vérification de présence',
                'Confirmer votre présence effective sur site lors des contrôles aléatoires.',
              ),
              const SizedBox(height: 24),

              // Note de confidentialite
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vos données de localisation ne sont jamais partagées avec des tiers. Vous pouvez révoquer cette autorisation à tout moment dans les paramètres de votre appareil.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Bouton Accepter
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await _saveConsent();
                    onAccepted();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Autoriser la localisation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bouton Refuser
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: onDeclined,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continuer sans localisation en arrière-plan',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReason(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

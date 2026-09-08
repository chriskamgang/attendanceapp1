import 'dart:async';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/bus_tracking.dart';
import '../../../data/services/api_exception.dart';
import '../../../data/services/session_service.dart';
import '../../../data/services/student_service.dart';
import '../../../routes/app_pages.dart';

/// Coque de l'espace étudiant : porte les cinq onglets de la barre basse.
class HomeController extends GetxController {
  final SessionService session = Get.find<SessionService>();
  final StudentService student = Get.find<StudentService>();

  final RxInt tab = 0.obs;

  AppUser? get user => session.user.value;

  String get greetingName {
    final name = user?.firstName ?? '';
    return name.isEmpty ? 'Étudiant' : name;
  }

  /// Salutation adaptée à l'heure d'ouverture de l'application.
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  GoogleMapController? _map;

  /// Suit la position du bus pour recentrer la caméra en continu.
  StreamSubscription<BusTracking?>? _busWatch;

  void onMapCreated(GoogleMapController map) {
    _map = map;
    _busWatch?.cancel();
    _busWatch = student.tracking.listen((suivi) {
      final position = suivi?.busPosition;
      if (position == null) return;

      _map?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    });
  }

  void changeTab(int index) => tab.value = index;

  /// Recharge suivi, pass, trajets et alertes.
  Future<void> reload() => student.refreshAll();

  void openNotifications() => Get.toNamed(Routes.NOTIFICATIONS);

  @override
  void onClose() {
    _busWatch?.cancel();
    _map?.dispose();
    super.onClose();
  }

  /// Ferme la session et ramène à l'accueil de connexion.
  ///
  /// La révocation du token côté serveur peut échouer — appareil hors
  /// ligne, token déjà expiré — sans que cela retienne l'utilisateur :
  /// la session locale disparaît dans tous les cas.
  Future<void> signOut() async {
    await session.signOut();
    Get.offAllNamed(Routes.WELCOMER);
  }

  /// Vrai pendant l'appel de suppression : l'écran bloque le bouton pour
  /// qu'un second appui ne relance pas la requête.
  final RxBool deleting = false.obs;

  /// Supprime le compte, puis renvoie à l'accueil de connexion.
  ///
  /// La confirmation est posée par la vue ; ici ne reste que l'appel et le
  /// sort réservé à l'échec. Un refus du serveur — cagnotte non soldée —
  /// laisse la session ouverte et affiche la raison.
  Future<void> deleteAccount() async {
    if (deleting.value) return;
    deleting.value = true;

    try {
      await session.deleteAccount();
      Get.offAllNamed(Routes.WELCOMER);
    } on ApiException catch (e) {
      Get.snackbar(
        'Suppression impossible',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } finally {
      deleting.value = false;
    }
  }
}

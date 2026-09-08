import 'dart:async';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/bus_tracking.dart';
import '../../../data/services/api_exception.dart';
import '../../../data/services/presence_service.dart';
import '../../../data/services/session_service.dart';
import '../../../data/services/student_service.dart';
import '../../../routes/app_pages.dart';
import '../../scolarite/controllers/scolarite_controller.dart';

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
  /// Recharge ce que l'écran montre.
  ///
  /// La scolarité vit dans son propre service : sans ce rappel, le bouton
  /// du bandeau actualisait le transport pendant que l'étudiant regardait
  /// ses cours, et rien ne bougeait sous ses yeux.
  Future<void> reload() async {
    await Future.wait([
      student.refreshAll(),
      if (Get.isRegistered<PresenceService>())
        Get.find<PresenceService>().rafraichir(),
      if (Get.isRegistered<ScolariteController>())
        Get.find<ScolariteController>().rafraichir(),
    ]);
  }

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
    if (signingOut.value) return;
    signingOut.value = true;

    try {
      await session.signOut();
      Get.offAllNamed(Routes.WELCOMER);
    } finally {
      // Le contrôleur peut avoir été démonté par le changement de route :
      // remettre le drapeau ne sert qu'au cas où la session survit, mais
      // le faire sans condition lèverait sur un Rx déjà disposé.
      if (!isClosed) signingOut.value = false;
    }
  }

  /// Vrai pendant la déconnexion : l'écran remplace le libellé du bouton
  /// par un indicateur et refuse un second appui.
  ///
  /// La révocation passe par le réseau — détachement du push, puis appel au
  /// serveur : sans ce signal, le bouton restait muet plusieurs secondes et
  /// l'utilisateur le pressait à nouveau, croyant l'avoir manqué.
  final RxBool signingOut = false.obs;

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

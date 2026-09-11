import 'package:get/get.dart';

import '../../../data/services/api_client.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/presence_service.dart';
import '../../../data/services/osm_service.dart';
import '../../../data/services/realtime_service.dart';
import '../../../data/services/student_service.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Le service survit aux changements d'onglet : il porte le suivi du bus.
    if (!Get.isRegistered<OsmService>()) {
      Get.put<OsmService>(OsmService(), permanent: true);
    }
    // StudentService expose la boîte partagée : elle doit exister avant lui.
    if (!Get.isRegistered<NotificationService>()) {
      Get.put<NotificationService>(
        NotificationService(api: Get.find<ApiClient>()),
        permanent: true,
      );
    }
    // Suivi poussé par le serveur : il complète le sondage sans le
    // remplacer, et reste sans effet si Reverb n'est pas joignable.
    if (!Get.isRegistered<RealtimeService>()) {
      Get.put<RealtimeService>(
        RealtimeService(api: Get.find<ApiClient>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<StudentService>()) {
      Get.put<StudentService>(
        StudentService(
          api: Get.find<ApiClient>(),
          realtime: Get.find<RealtimeService>(),
        ),
        permanent: true,
      );
    }
    // Le pointage de présence a besoin du GPS : le même service que celui
    // du chauffeur, enregistré ici car l'étudiant n'ouvre pas son écran.
    if (!Get.isRegistered<LocationService>()) {
      Get.put<LocationService>(LocationService(), permanent: true);
    }
    if (!Get.isRegistered<PresenceService>()) {
      Get.put<PresenceService>(
        PresenceService(
          api: Get.find<ApiClient>(),
          location: Get.find<LocationService>(),
        ),
        permanent: true,
      );
    }
    Get.lazyPut<HomeController>(() => HomeController());
  }
}

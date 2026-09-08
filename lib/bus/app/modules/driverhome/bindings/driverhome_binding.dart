import 'package:get/get.dart';

import '../../../data/services/api_client.dart';
import '../../../data/services/boarding_service.dart';
import '../../../data/services/driver_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/osm_service.dart';
import '../controllers/driverhome_controller.dart';

class DriverhomeBinding extends Bindings {
  @override
  void dependencies() {
    // Le service survit aux changements d'onglet : il porte le cycle de
    // pointage en cours et la position diffusée.
    if (!Get.isRegistered<OsmService>()) {
      Get.put<OsmService>(OsmService(), permanent: true);
    }
    // Le chauffeur reçoit pannes et missions de secours dans la même
    // boîte que les alertes de l'étudiant.
    if (!Get.isRegistered<NotificationService>()) {
      Get.put<NotificationService>(
        NotificationService(api: Get.find<ApiClient>()),
        permanent: true,
      );
    }
    // La position réelle commande tout le pointage : le backend refuse une
    // étape validée hors de la zone de l'arrêt (CDC §3.4).
    if (!Get.isRegistered<LocationService>()) {
      Get.put<LocationService>(LocationService(), permanent: true);
    }
    // Billettique : un ticket consommé engage le pass d'un étudiant.
    if (!Get.isRegistered<BoardingService>()) {
      Get.put<BoardingService>(
        BoardingService(api: Get.find<ApiClient>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DriverService>()) {
      Get.put<DriverService>(
        DriverService(
          api: Get.find<ApiClient>(),
          location: Get.find<LocationService>(),
          boarding: Get.find<BoardingService>(),
        ),
        permanent: true,
      );
    }
    Get.lazyPut<DriverhomeController>(() => DriverhomeController());
  }
}

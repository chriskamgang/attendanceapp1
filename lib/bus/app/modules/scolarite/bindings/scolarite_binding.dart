import 'package:get/get.dart';

import '../../../data/services/api_client.dart';
import '../../../data/services/scolarite_service.dart';
import '../controllers/scolarite_controller.dart';

class ScolariteBinding extends Bindings {
  @override
  void dependencies() {
    // Le service est permanent : l'étudiant revient sur sa scolarité entre
    // deux consultations du bus, et le réinstaller à chaque passage
    // relancerait ses appels sans raison.
    if (!Get.isRegistered<ScolariteService>()) {
      Get.put<ScolariteService>(
        ScolariteService(api: Get.find<ApiClient>()),
        permanent: true,
      );
    }
    Get.lazyPut<ScolariteController>(() => ScolariteController());
  }
}

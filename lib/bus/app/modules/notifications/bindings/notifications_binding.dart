import 'package:get/get.dart';

import '../../../data/services/api_client.dart';
import '../../../data/services/notification_service.dart';

class NotificationsBinding extends Bindings {
  @override
  void dependencies() {
    // L'écran est ouvert depuis l'espace étudiant comme depuis l'espace
    // chauffeur : il ne dépend que de la boîte commune, jamais du service
    // d'un rôle. Le service peut manquer si l'écran est atteint par lien
    // direct ou depuis une bannière push.
    if (!Get.isRegistered<NotificationService>()) {
      Get.put<NotificationService>(
        NotificationService(api: Get.find<ApiClient>()),
        permanent: true,
      );
    }
  }
}

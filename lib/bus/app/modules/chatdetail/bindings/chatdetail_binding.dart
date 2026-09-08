import 'package:get/get.dart';

import '../controllers/chatdetail_controller.dart';

class ChatdetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatdetailController>(() => ChatdetailController());
  }
}

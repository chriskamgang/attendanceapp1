import 'package:get/get.dart';

import '../controllers/seeting_controller.dart';

class SeetingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SeetingController>(() => SeetingController());
  }
}

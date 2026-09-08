import 'package:get/get.dart';

import '../controllers/pin_controller.dart';

class PinBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PinController>(() => PinController());
  }
}

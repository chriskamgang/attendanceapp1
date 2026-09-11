import 'package:get/get.dart';

import '../controllers/driverlogin_controller.dart';

class DriverloginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DriverloginController>(() => DriverloginController());
  }
}

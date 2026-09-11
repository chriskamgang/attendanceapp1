import 'package:get/get.dart';

import '../controllers/completeprofile_controller.dart';

class CompleteprofileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CompleteprofileController>(() => CompleteprofileController());
  }
}

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:tariqi/web_services/dio_config.dart';
import 'package:tariqi/web_services/dio_payment_config.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/services/driver_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DioClient());
    Get.put(DioPaymentClient());
    Get.put(AuthController());
    Get.put(DriverService());
  }
}

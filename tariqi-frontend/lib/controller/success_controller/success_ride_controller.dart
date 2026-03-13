import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/main.dart';
import 'package:tariqi/models/ride_request_model.dart';

class SuccessRideController extends GetxController {
  RxString pickPoint = "".obs;
  RxString targetPoint = "".obs;
  RxList<RideRequestModel> requests = RxList<RideRequestModel>([]);

  Rx<RequestState> requestState = RequestState.none.obs;

  initialServices() {
    requestState.value = RequestState.loading;
    requests.add(RideRequestModel.fromJson(Get.arguments["request"]));
    pickPoint.value = Get.arguments["pickPoint"];
    targetPoint.value = Get.arguments["targetPoint"];
    requestState.value = RequestState.success;
  }

    void gotoTripsScreen ({required String requestId}) {
    Get.offNamed(AppRoutesNames.userTripsScreen);
    sharedPreferences.setString("request_id", requestId);
  }

  @override
  void onInit() {
    initialServices();
    super.onInit();
  }
}

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewController extends GetxController {
  late WebViewController webController;
  String url = "";
  PaymentWebViewController({required BuildContext context});

  handleWebViewPageController({required BuildContext context}) {
    webController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // Update loading bar.
              },
              onPageStarted: (String url) {},
              onPageFinished: (String url) {},
              onHttpError: (HttpResponseError error) {},
              onWebResourceError: (WebResourceError error) {},
              onNavigationRequest: (NavigationRequest request) {
                if (request.url.contains("success")) {
                  Navigator.pop(context);

                  AwesomeDialog(
                    dialogType: DialogType.success,
                    context: context,
                    title: "Payment Success",
                    body: const Text("Payment Success"),
                    btnOkText: "Home",
                    btnOkOnPress: () {
                      Get.offNamed(AppRoutesNames.homeScreen);
                    },
                  ).show();
                } else if (request.url.contains("failed")) {
                  Navigator.pop(context);
                  AwesomeDialog(
                    dialogType: DialogType.error,
                    context: context,
                    title: "Payment Failed",
                    body: const Text("Payment Failed Please Try Again"),
                    btnCancelText: "Try Again",
                    btnCancelOnPress: () {
                      Get.offNamed(AppRoutesNames.paymentScreen);
                    },
                  ).show();
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(
            Uri.parse(url),
          );
  }


  @override
  void onInit() {
    url = Get.arguments["url"];
    handleWebViewPageController(context: Get.context!);
    super.onInit();
  }
}

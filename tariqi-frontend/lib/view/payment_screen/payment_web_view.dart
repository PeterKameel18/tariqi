import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/payment_controller/payment_webview_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatelessWidget {
  const WebViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    PaymentWebViewController controller = Get.put(PaymentWebViewController(context: context));
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: WebViewWidget(controller: controller.webController),
    );
  }
}

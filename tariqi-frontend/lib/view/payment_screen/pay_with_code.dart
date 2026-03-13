import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/payment_controller/pay_code_controller.dart';

class PayWithCode extends GetView<PayCodeController> {
  const PayWithCode({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PayCodeController());
    return Scaffold(
      appBar: AppBar(
        title: Text("Pay With Code"),
      ),
      body: Center(
        child: Text(controller.paymentCode.toString()),
      ),
    );
  }
}
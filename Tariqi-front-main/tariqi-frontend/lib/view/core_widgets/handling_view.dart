import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/images/app_images.dart';

class HandlingView extends StatelessWidget {
  final RequestState requestState;
  final Widget widget;
  const HandlingView({
    super.key,
    required this.requestState,
    required this.widget,
  });

  @override
  Widget build(BuildContext context) {
    return requestState == RequestState.offline
        ? Center(child: Lottie.asset(AppImages.offline))
        : requestState == RequestState.loading
        ? Center(child: Lottie.asset(AppImages.loading))
        : requestState == RequestState.failed
        ? Center(child: Lottie.asset(AppImages.failed))
        : requestState == RequestState.online
        ? widget
        : widget;
  }
}

import 'package:flutter/material.dart';

class PopScopeWidget extends StatelessWidget {
  final Widget childWidget;
  final void Function(bool, Object?) popAction;
  const PopScopeWidget({
    super.key,
    required this.childWidget,
    required this.popAction,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: popAction,
      child: childWidget,
    );
  }
}

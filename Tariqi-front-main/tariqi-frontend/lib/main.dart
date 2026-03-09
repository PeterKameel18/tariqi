import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/initial_binding.dart';
import 'package:tariqi/const/routes/routes.dart';
import 'package:tariqi/const/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences sharedPreferences;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sharedPreferences = await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      initialBinding: InitialBinding(),
      getPages: routes,
    );
  }
}

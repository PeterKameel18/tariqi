import 'dart:developer';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends GetxController {
  RxString token = ''.obs;
  RxBool isLoggedIn = false.obs;

  Future<void> saveToken(String newToken) async {
    log("📝 Saving new token: ${newToken.substring(0, math.min(10, newToken.length))}...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', newToken);
    token.value = newToken;
    isLoggedIn.value = true;
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('authToken') ?? '';
    
    // Make sure token doesn't have unwanted whitespace
    token.value = storedToken.trim();
    isLoggedIn.value = token.isNotEmpty;
    
    if (token.isEmpty) {
      log("⚠️ No token found in storage");
    } else {
      // Log full token for debugging - REMOVE IN PRODUCTION
      log("🔑 FULL TOKEN: ${token.value}");
    }
  }

  Future<void> clearToken() async {
    log("🧹 Clearing token");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    token.value = '';
    isLoggedIn.value = false;
  }

  bool isValidToken() {
    return token.value.isNotEmpty;
  }

  @override
  void onInit() {
    loadToken();
    super.onInit();
  }
}

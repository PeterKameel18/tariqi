/// A utility class that provides static paths to various image and animation assets
/// used in the application. The paths are organized into categories such as splash,
/// authentication, home, and lottie animations.
abstract class AppImages {
  static String imagesPath = "assets/images/";
  static String googleLogin = "${imagesPath}google.png";
  static String rideImage = "${imagesPath}ride.png";
  static String packageImage = "${imagesPath}package.png";
  static String successImage = "${imagesPath}succes_image.png";

  static String lottiePath = "assets/lottie/";
  static String loading = "${lottiePath}loading.json";
  static String failed = "${lottiePath}failed.json";
  static String offline = "${lottiePath}offline.json";
}
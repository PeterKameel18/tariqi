import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NSLog("PHONE_AUTH iOS didFinishLaunching urlOptions=\(String(describing: launchOptions))")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    NSLog("PHONE_AUTH iOS openURL url=\(url.absoluteString) options=\(options)")
    if Auth.auth().canHandle(url) {
      NSLog("PHONE_AUTH iOS openURL handledByFirebase=true")
      return true
    }
    NSLog("PHONE_AUTH iOS openURL handledByFirebase=false")
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    NSLog(
      "PHONE_AUTH iOS continueUserActivity type=\(userActivity.activityType) url=\(userActivity.webpageURL?.absoluteString ?? "nil")"
    )
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

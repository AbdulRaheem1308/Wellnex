import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register background sync task identifier
    WorkmanagerPlugin.registerTask(withIdentifier: "wellnex.backgroundSync")
    
    // Set minimum background fetch interval (15 minutes)
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

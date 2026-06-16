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
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "wellnex.backgroundSync")
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "wellnex.backgroundSync", frequency: NSNumber(value: 20 * 60))
    
    // Set minimum background fetch interval (15 minutes)
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

import UIKit
import Flutter
import GoogleMaps // <-- ADD THIS

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // --- ADD THESE TWO LINES ---
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String ?? ""
    GMSServices.provideAPIKey(mapsApiKey)
    // ---------------------------

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
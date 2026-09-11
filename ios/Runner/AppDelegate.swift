import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configurer Firebase en natif (nécessaire pour les push notifications iOS)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Clé Google Maps, lue dans Info.plist plutôt qu'écrite ici : elle suit
    // ainsi la même voie que sur Android, où le build l'injecte depuis
    // local.properties. Google Maps ne sert qu'au rendu de la carte — le
    // géocodage et les itinéraires passent par OpenStreetMap (OsmService).
    if let cle = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !cle.isEmpty {
      GMSServices.provideAPIKey(cle)
    }
    GeneratedPluginRegistrant.register(with: self)

    // Enregistrer pour les notifications push
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Transmettre le token APNs à Firebase
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}

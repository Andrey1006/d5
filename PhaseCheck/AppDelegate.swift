import SwiftUI
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().delegate = self
        
        Messaging.messaging().delegate = self
        
        let window = UIWindow()
        window.rootViewController = UIHostingController(rootView: AppRootView())
        self.window = window
        window.makeKeyAndVisible()
        
        AppsFlyerLib.shared().appsFlyerDevKey = "dyXAyjGqFgjsHhkp5VjYzF"
        AppsFlyerLib.shared().appleAppID = "6766565672"
        AppsFlyerLib.shared().delegate = self
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        AppsFlyerLib.shared().start()
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        UserDefaults.standard.setValue(fcmToken, forKey: "pushToken")
        if let token = fcmToken, !token.isEmpty {
            Task { await ConfigManager.shared.sendPushToken(token) }
        }
    }
}

extension AppDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let customUrl = userInfo["url"] as? String, !customUrl.isEmpty {
            NotificationCenter.default.post(name: NSNotification.Name("PushURLReceived"), object: customUrl)
        }

        completionHandler()
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let dict = conversionInfo.reduce(into: [String: Any]()) { result, item in
            if let key = item.key as? String { result[key] = item.value }
        }
        
        let status = dict["af_status"] as? String ?? ""
        
        if status == "Organic" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.fetchConversionDataByAPI()
            }
        } else {
            self.saveConversionData(dict)
        }
    }
    
    private func saveConversionData(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            UserDefaults.standard.setValue(data, forKey: "conversionInfo")
            UserDefaults.standard.setValue(true, forKey: "recieved")
        }
    }

    private func fetchConversionDataByAPI() {
        let devKey = AppsFlyerLib.shared().appsFlyerDevKey
        let appleAppID = AppsFlyerLib.shared().appleAppID
        let afUID = AppsFlyerLib.shared().getAppsFlyerUID()
        
        let urlString = "https://api2.appsflyer.com/inappevent/\(appleAppID)?devkey=\(devKey)&device_id=\(afUID)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    self.saveConversionData(json)
                }
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.setValue(true, forKey: "recieved")
                }
            }
        }.resume()
    }
    
    func onConversionDataFail(_ error: Error) {
        UserDefaults.standard.setValue("", forKey: "conversionInfo")
        UserDefaults.standard.setValue(true, forKey: "recieved")
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        let dict = attributionData.reduce(into: [String: Any]()) { result, item in
            if let key = item.key as? String { result[key] = item.value }
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            UserDefaults.standard.setValue(data, forKey: "conversionInfo")
        }
        UserDefaults.standard.setValue(true, forKey: "recieved")
    }

    func onAppOpenAttributionFailure(_ error: Error) {
        UserDefaults.standard.setValue(true, forKey: "recieved")
    }
}


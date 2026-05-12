import SwiftUI
import UserNotifications

struct NotificationRequestView: View {
    @AppStorage("lastNotificationRequest") private var lastNotificationRequest: Double = 0
    
    var isReadyForNotificationRequest: Bool {
        let currentTime = Date().timeIntervalSince1970
        return (currentTime - lastNotificationRequest) >= 259200
    }
    
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color(red: 0x0F/255, green: 0x13/255, blue: 0x20/255)
            .ignoresSafeArea()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    Image(.lightning)
                        .resizable()
                        .scaledToFit()

                    VStack(spacing: 20) {
                        Spacer()

                        Text("ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Stay tuned with best offers")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        Button(action: handleYesAction) {
                            Text("Yes, I Want Bonuses!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)

                        Button(action: handleSkipAction) {
                            Text("Skip")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                }

                VStack(spacing: 0) {
                    Image(.lightning)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 40)

                    VStack(spacing: 20) {
                        Text("ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Stay tuned with best offers")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        Button(action: handleYesAction) {
                            Text("Yes, I Want Bonuses!")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)

                        Button(action: handleSkipAction) {
                            Text("Skip")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func handleYesAction() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    lastNotificationRequest = Date.distantFuture.timeIntervalSince1970
                } else {
                    lastNotificationRequest = Date().timeIntervalSince1970
                }
                onComplete()
            }
        }
    }
    
    private func handleSkipAction() {
        lastNotificationRequest = Date().timeIntervalSince1970
        onComplete()
    }
}

#Preview {
    NotificationRequestView(onComplete: {})
}

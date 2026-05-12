import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        let fcmOptions = request.content.userInfo["fcm_options"] as? [String: Any]
        let imageURLString = fcmOptions?["image"] as? String
                          ?? request.content.userInfo["image"] as? String

        guard let bestAttemptContent,
              let imageURLString,
              let imageURL = URL(string: imageURLString) else {
            contentHandler(bestAttemptContent ?? request.content.mutableCopy() as! UNMutableNotificationContent)
            return
        }

        downloadImage(from: imageURL) { attachment in
            if let attachment {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
            guard let tempURL else {
                completion(nil)
                return
            }

            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let destURL = tempURL.deletingLastPathComponent().appendingPathComponent("image.\(ext)")

            try? FileManager.default.moveItem(at: tempURL, to: destURL)

            let attachment = try? UNNotificationAttachment(identifier: "image", url: destURL, options: nil)
            completion(attachment)
        }.resume()
    }
}

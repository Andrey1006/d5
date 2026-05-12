import Foundation
import AppsFlyerLib
import FirebaseRemoteConfig

private struct SignupResponse: Decodable {
    let cid: String
    let token: String
}

private struct ValidationResponse: Decodable {
    let uid: String?
    let cid: String?
    let support: String?
}

@MainActor
class ConfigManager {
    static let shared = ConfigManager()

    private let tokenKey = "sessionCredential"

    private init() {}

    private func remoteBase() async -> String? {
        let rc = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        rc.configSettings = settings
        do {
            let _ = try await rc.fetchAndActivate()
            let val = rc["configDom"].stringValue
            return val.isEmpty ? nil : val
        } catch {
            return nil
        }
    }

    private func signup(base: String) async -> String? {
        guard let endpoint = URL(string: "\(base)/api/v1.0/auth/signup") else { return nil }

        var params: [String: Any] = [:]
        if let data = UserDefaults.standard.data(forKey: "conversionInfo"),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            params = dict
        }
        params["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()

        let payload: [String: Any] = [
            "uid": UUID().uuidString,
            "params": params
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(SignupResponse.self, from: data)
            UserDefaults.standard.set(decoded.token, forKey: tokenKey)
            return decoded.token
        } catch {
            return nil
        }
    }

    private func validateToken(base: String, token: String) async -> String? {
        guard let endpoint = URL(string: "\(base)/api/v1.0/auth/validatetoken?update=true") else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(ValidationResponse.self, from: data)
            let destination = decoded.support
            return (destination != nil && destination!.isEmpty == false) ? destination : nil
        } catch {
            return nil
        }
    }

    func sendPushToken(_ pushToken: String) async {
        guard let base = await remoteBase() else { return }
        guard let sessionToken = UserDefaults.standard.string(forKey: tokenKey), !sessionToken.isEmpty else { return }
        guard let endpoint = URL(string: "\(base)/api/v1.0/players/me/pushToken/\(pushToken)") else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let _ = try await URLSession.shared.data(for: request)
        } catch {}
    }

    func fetchDestination() async -> String? {
        guard let base = await remoteBase() else { return nil }

        let cachedToken = UserDefaults.standard.string(forKey: tokenKey)
        let token: String
        if let existing = cachedToken, !existing.isEmpty {
            token = existing
        } else {
            guard let fresh = await signup(base: base) else { return nil }
            token = fresh
        }

        return await validateToken(base: base, token: token)
    }
}

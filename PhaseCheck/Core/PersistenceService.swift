
import Foundation

struct PersistedPayload: Codable {
    var projects: [Project]
    var selectedProjectId: UUID?
    var settings: AppSettings
    var templates: [LoadTemplate]
}

enum PersistenceService {
    private static let fileName = "phasecheck_store.json"
    private static let appSupportFolderName = "ZeuphaseCheck"
    private static let exportFileName = "ZeuphaseCheck_export.json"

    private static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(appSupportFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> PersistedPayload? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PersistedPayload.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ payload: PersistedPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Save failed: \(error)")
        }
    }

    static func exportURL(for payload: PersistedPayload) throws -> URL {
        let data = try JSONEncoder().encode(payload)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(exportFileName)
        try data.write(to: tmp, options: [.atomic])
        return tmp
    }

    static func importPayload(from importURL: URL) throws -> PersistedPayload {
        let data = try Data(contentsOf: importURL)
        return try JSONDecoder().decode(PersistedPayload.self, from: data)
    }
}

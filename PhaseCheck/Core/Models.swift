
import Foundation

enum PhaseLine: String, CaseIterable, Codable, Identifiable, Hashable {
    case L1, L2, L3
    var id: String { rawValue }
}

enum LoadInputKind: String, Codable, CaseIterable {
    case current
    case power
}

enum LoadConnectionKind: String, Codable, CaseIterable {
    case singlePhase
    case threePhaseBalanced
}

enum LoadCategory: String, Codable, CaseIterable {
    case lighting, outlets, hvac, motor, kitchen, other
}

enum LoadPriority: String, Codable, CaseIterable, Comparable {
    case low
    case normal
    case high
    case critical

    var title: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var sortRank: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    static func < (lhs: LoadPriority, rhs: LoadPriority) -> Bool {
        lhs.sortRank < rhs.sortRank
    }
}

struct LoadDevice: Identifiable, Equatable {
    var id: UUID
    var name: String
    var category: LoadCategory
    var phase: PhaseLine
    var isIncluded: Bool
    var inputKind: LoadInputKind
    var currentAmps: Double
    var powerKW: Double
    var connectionKind: LoadConnectionKind
    var customPowerFactor: Double?
    var tags: [String]
    var priority: LoadPriority

    func effectivePowerFactor(projectDefault: Double) -> Double {
        let raw = customPowerFactor ?? projectDefault
        return max(0.05, min(1, raw))
    }
}

extension LoadDevice: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, category, phase, isIncluded, inputKind, currentAmps, powerKW
        case connectionKind, customPowerFactor, tags, priority
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(LoadCategory.self, forKey: .category)
        phase = try c.decode(PhaseLine.self, forKey: .phase)
        isIncluded = try c.decode(Bool.self, forKey: .isIncluded)
        inputKind = try c.decode(LoadInputKind.self, forKey: .inputKind)
        currentAmps = try c.decode(Double.self, forKey: .currentAmps)
        powerKW = try c.decode(Double.self, forKey: .powerKW)
        connectionKind = try c.decodeIfPresent(LoadConnectionKind.self, forKey: .connectionKind) ?? .singlePhase
        customPowerFactor = try c.decodeIfPresent(Double.self, forKey: .customPowerFactor)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        priority = try c.decodeIfPresent(LoadPriority.self, forKey: .priority) ?? .normal
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(phase, forKey: .phase)
        try c.encode(isIncluded, forKey: .isIncluded)
        try c.encode(inputKind, forKey: .inputKind)
        try c.encode(currentAmps, forKey: .currentAmps)
        try c.encode(powerKW, forKey: .powerKW)
        try c.encode(connectionKind, forKey: .connectionKind)
        try c.encodeIfPresent(customPowerFactor, forKey: .customPowerFactor)
        try c.encode(tags, forKey: .tags)
        try c.encode(priority, forKey: .priority)
    }
}

struct ProjectElectricalContext: Codable, Equatable {
    var lineToLineVoltageVolts: Double
    var lineToNeutralVoltageVolts: Double
    var defaultPowerFactor: Double
    var maxCurrentPerPhaseAmps: Double?
    var gridLabel: String
}

struct BalanceSnapshot: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var note: String
    var ampsByPhase: [PhaseLine: Double]
    var imbalancePercent: Double
    var statusToken: String
}

struct SavedScenario: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var phaseByLoadId: [UUID: PhaseLine]
    var ampsByPhase: [PhaseLine: Double]
    var imbalancePercent: Double
}

struct Project: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var context: ProjectElectricalContext
    var loads: [LoadDevice]
    var snapshots: [BalanceSnapshot]
    var scenarios: [SavedScenario]

    static func newDraft() -> Project {
        Project(
            id: UUID(),
            name: "New panel",
            createdAt: Date(),
            context: ProjectElectricalContext(
                lineToLineVoltageVolts: 400,
                lineToNeutralVoltageVolts: 230,
                defaultPowerFactor: 0.92,
                maxCurrentPerPhaseAmps: 25,
                gridLabel: "3×230 / 400 V"
            ),
            loads: [],
            snapshots: [],
            scenarios: []
        )
    }
}

struct ThresholdSettings: Codable, Equatable {
    var yellowImbalancePercent: Double
    var redImbalancePercent: Double
    var criticalCurrentPercentOfLimit: Double
}

struct AppSettings: Codable, Equatable {
    var preferPowerInsteadOfCurrent: Bool
    var thresholds: ThresholdSettings
}

struct LoadTemplate: Identifiable, Equatable {
    var id: UUID
    var name: String
    var category: LoadCategory
    var defaultInputKind: LoadInputKind
    var defaultCurrentAmps: Double
    var defaultPowerKW: Double
    var connectionKind: LoadConnectionKind
    var customPowerFactor: Double?
}

extension LoadTemplate: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, category, defaultInputKind, defaultCurrentAmps, defaultPowerKW
        case connectionKind, customPowerFactor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(LoadCategory.self, forKey: .category)
        defaultInputKind = try c.decode(LoadInputKind.self, forKey: .defaultInputKind)
        defaultCurrentAmps = try c.decode(Double.self, forKey: .defaultCurrentAmps)
        defaultPowerKW = try c.decode(Double.self, forKey: .defaultPowerKW)
        connectionKind = try c.decodeIfPresent(LoadConnectionKind.self, forKey: .connectionKind) ?? .singlePhase
        customPowerFactor = try c.decodeIfPresent(Double.self, forKey: .customPowerFactor)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(defaultInputKind, forKey: .defaultInputKind)
        try c.encode(defaultCurrentAmps, forKey: .defaultCurrentAmps)
        try c.encode(defaultPowerKW, forKey: .defaultPowerKW)
        try c.encode(connectionKind, forKey: .connectionKind)
        try c.encodeIfPresent(customPowerFactor, forKey: .customPowerFactor)
    }
}

extension LoadCategory {
    var title: String {
        switch self {
        case .lighting: return "Lighting"
        case .outlets: return "Outlets"
        case .hvac: return "HVAC"
        case .motor: return "Motors"
        case .kitchen: return "Kitchen"
        case .other: return "Other"
        }
    }
}

extension PhaseLine {
    var shortTitle: String { rawValue }
}

extension LoadConnectionKind {
    var shortTitle: String {
        switch self {
        case .singlePhase: return "1φ"
        case .threePhaseBalanced: return "3φ bal."
        }
    }
}

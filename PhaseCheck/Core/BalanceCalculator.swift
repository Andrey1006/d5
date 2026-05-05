
import Foundation

enum BalanceStatus: Equatable {
    case balanced
    case skewed
    case critical
}

struct PhaseSummary: Equatable {
    var amps: Double
    var percentOfMax: Double
}

struct BalanceReport: Equatable {
    var ampsByPhase: [PhaseLine: Double]
    var totalAmps: Double
    var averageAmps: Double
    var imbalancePercent: Double
    var status: BalanceStatus
    var warnings: [String]
}

enum BalanceCalculator {
    static func resolvedLineCurrentAmps(for load: LoadDevice, context: ProjectElectricalContext) -> Double {
        guard load.isIncluded else { return 0 }
        let cosφ = load.effectivePowerFactor(projectDefault: context.defaultPowerFactor)
        switch load.connectionKind {
        case .singlePhase:
            switch load.inputKind {
            case .current:
                return max(0, load.currentAmps)
            case .power:
                let u = context.lineToNeutralVoltageVolts
                guard u > 0 else { return 0 }
                return max(0, load.powerKW) * 1000 / (u * cosφ)
            }
        case .threePhaseBalanced:
            switch load.inputKind {
            case .current:
                return max(0, load.currentAmps)
            case .power:
                let uLL = context.lineToLineVoltageVolts
                let denom = sqrt(3) * uLL * cosφ
                guard denom > 0 else { return 0 }
                return max(0, load.powerKW) * 1000 / denom
            }
        }
    }

    static func resolvedCurrentAmps(for load: LoadDevice, context: ProjectElectricalContext) -> Double {
        resolvedLineCurrentAmps(for: load, context: context)
    }

    static func ampsByPhase(loads: [LoadDevice], context: ProjectElectricalContext) -> [PhaseLine: Double] {
        ampsByPhase(loads: loads, context: context, overridePhase: { _ in nil })
    }

    static func ampsByPhase(
        loads: [LoadDevice],
        context: ProjectElectricalContext,
        overridePhase: (UUID) -> PhaseLine?
    ) -> [PhaseLine: Double] {
        var map: [PhaseLine: Double] = [.L1: 0, .L2: 0, .L3: 0]
        for load in loads {
            accumulate(load: load, context: context, overridePhase: overridePhase(load.id), into: &map)
        }
        return map
    }

    private static func accumulate(load: LoadDevice, context: ProjectElectricalContext, overridePhase: PhaseLine?, into map: inout [PhaseLine: Double]) {
        guard load.isIncluded else { return }
        let iLine = resolvedLineCurrentAmps(for: load, context: context)
        switch load.connectionKind {
        case .singlePhase:
            let phase = overridePhase ?? load.phase
            map[phase, default: 0] += iLine
        case .threePhaseBalanced:
            for p in PhaseLine.allCases {
                map[p, default: 0] += iLine
            }
        }
    }

    static func imbalancePercent(ampsByPhase: [PhaseLine: Double]) -> Double {
        let values = PhaseLine.allCases.map { max(0, ampsByPhase[$0] ?? 0) }
        let maxV = values.max() ?? 0
        let minV = values.min() ?? 0
        guard maxV > 0.0001 else { return 0 }
        return (maxV - minV) / maxV * 100
    }

    static func report(
        loads: [LoadDevice],
        context: ProjectElectricalContext,
        thresholds: ThresholdSettings,
        phaseOverride: ((UUID) -> PhaseLine?)? = nil
    ) -> BalanceReport {
        let map: [PhaseLine: Double]
        if let resolver = phaseOverride {
            map = ampsByPhase(loads: loads, context: context, overridePhase: resolver)
        } else {
            map = ampsByPhase(loads: loads, context: context)
        }

        let values = PhaseLine.allCases.map { map[$0] ?? 0 }
        let total = values.reduce(0, +)
        let avg = values.isEmpty ? 0 : total / Double(values.count)
        let imb = imbalancePercent(ampsByPhase: map)

        var warnings: [String] = []
        if let limit = context.maxCurrentPerPhaseAmps, limit > 0 {
            for p in PhaseLine.allCases {
                let a = map[p] ?? 0
                if a > limit {
                    warnings.append("Limit exceeded on \(p.rawValue): \(formatA(a)) > \(formatA(limit))")
                } else if a >= limit * (thresholds.criticalCurrentPercentOfLimit / 100) {
                    warnings.append("Near limit on \(p.rawValue): \(formatA(a)) of \(formatA(limit))")
                }
            }
        }

        let status: BalanceStatus
        if imb >= thresholds.redImbalancePercent || warnings.contains(where: { $0.hasPrefix("Limit exceeded") }) {
            status = .critical
        } else if imb >= thresholds.yellowImbalancePercent || !warnings.isEmpty {
            status = .skewed
        } else {
            status = .balanced
        }

        return BalanceReport(
            ampsByPhase: map,
            totalAmps: total,
            averageAmps: avg,
            imbalancePercent: imb,
            status: status,
            warnings: warnings
        )
    }

    static func formatA(_ v: Double) -> String {
        String(format: "%.1f A", v)
    }

    static func formatPercent(_ v: Double) -> String {
        String(format: "%.1f%%", v)
    }

    static func suggestedPhases(loads: [LoadDevice], context: ProjectElectricalContext) -> [UUID: PhaseLine] {
        let active = loads.filter(\.isIncluded)
        var sums: [PhaseLine: Double] = [.L1: 0, .L2: 0, .L3: 0]
        var result: [UUID: PhaseLine] = [:]

        for p in PhaseLine.allCases {
            for load in active where load.connectionKind == .threePhaseBalanced {
                let i = resolvedLineCurrentAmps(for: load, context: context)
                sums[p, default: 0] += i
            }
        }

        let singles = active.filter { $0.connectionKind == .singlePhase }
            .sorted { resolvedLineCurrentAmps(for: $0, context: context) > resolvedLineCurrentAmps(for: $1, context: context) }

        for load in singles {
            let i = resolvedLineCurrentAmps(for: load, context: context)
            let best = PhaseLine.allCases.min(by: { sums[$0, default: 0] < sums[$1, default: 0] }) ?? .L1
            result[load.id] = best
            sums[best, default: 0] += i
        }
        return result
    }
}

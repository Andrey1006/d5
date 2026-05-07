
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
    var neutralCurrentAmps: Double
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

    /// Neutral current magnitude (ideal 120° phase displacement, ignoring harmonics).
    /// Formula: |In| = sqrt(Ia^2 + Ib^2 + Ic^2 - Ia*Ib - Ib*Ic - Ic*Ia)
    static func neutralCurrentAmps(ampsByPhase: [PhaseLine: Double]) -> Double {
        let ia = max(0, ampsByPhase[.L1] ?? 0)
        let ib = max(0, ampsByPhase[.L2] ?? 0)
        let ic = max(0, ampsByPhase[.L3] ?? 0)
        let v = ia * ia + ib * ib + ic * ic - ia * ib - ib * ic - ic * ia
        return sqrt(max(0, v))
    }

    private static let standardBreakerSeriesAmps: [Double] = [6, 10, 13, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125]

    /// Suggests a breaker nominal current from a standard series (rule-of-thumb).
    /// Multiplier defaults to 1.25 for continuous-load margin; adjust if needed.
    static func suggestedBreakerAmps(forPhaseCurrentAmps iPhase: Double, multiplier: Double = 1.25) -> Double? {
        let target = max(0, iPhase) * max(1, multiplier)
        guard target > 0 else { return nil }
        return standardBreakerSeriesAmps.first(where: { $0 >= target }) ?? standardBreakerSeriesAmps.last
    }

    /// Very rough minimum copper conductor cross-section suggestion by breaker rating.
    /// This is intentionally conservative and MUST be verified with local code + installation method.
    static func suggestedCopperCableMm2(forBreakerAmps inAmps: Double) -> Double? {
        guard inAmps > 0 else { return nil }
        switch inAmps {
        case ...16: return 1.5
        case ...25: return 2.5
        case ...32: return 4
        case ...40: return 6
        case ...63: return 10
        case ...80: return 16
        case ...100: return 25
        default: return 35
        }
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
        let neutral = neutralCurrentAmps(ampsByPhase: map)

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

        if neutral > 0 {
            let maxPhase = (values.max() ?? 0)
            if maxPhase > 0, neutral >= maxPhase * 0.75 {
                warnings.append("High neutral current: \(formatA(neutral)) (≈\(Int((neutral / maxPhase) * 100))% of max phase)")
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
            neutralCurrentAmps: neutral,
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

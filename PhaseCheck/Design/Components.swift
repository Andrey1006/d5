
import SwiftUI

struct PCScreenBackground: View {
    var body: some View {
        ZStack {
            PCColor.base.ignoresSafeArea()
            LinearGradient(
                colors: [PCColor.structure.opacity(0.25), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }
}

struct PCCard<Content: View>: View {
    var topAccent: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PCColor.layer)
            .overlay(alignment: .top) {
                if let topAccent {
                    Rectangle()
                        .fill(topAccent)
                        .frame(height: PCMetrics.topAccentHeight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PCMetrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PCMetrics.cornerRadius, style: .continuous)
                    .stroke(PCColor.structure, lineWidth: PCMetrics.borderWidth)
            )
    }
}

struct PCGradientButton: View {
    let title: String
    var gradient: LinearGradient = PCGradients.indigoBlue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(gradient)
                .clipShape(RoundedRectangle(cornerRadius: PCMetrics.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PCMetrics.cornerRadiusSmall, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PCOutlineButton: View {
    let title: String
    var color: Color = PCColor.dataBlue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(color)
                .background(PCColor.structure.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: PCMetrics.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PCMetrics.cornerRadiusSmall, style: .continuous)
                        .stroke(color.opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PhaseBarsView: View {
    var ampsByPhase: [PhaseLine: Double]
    var maxScale: Double?
    var orientation: Axis = .horizontal

    private var maxA: Double {
        let m = PhaseLine.allCases.map { ampsByPhase[$0] ?? 0 }.max() ?? 0
        if let maxScale, maxScale > 0 { return max(m, maxScale) }
        return max(m, 1)
    }

    var body: some View {
        Group {
            if orientation == .horizontal {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(PhaseLine.allCases) { phase in
                        barColumn(phase: phase)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 10) {
                    ForEach(PhaseLine.allCases) { phase in
                        barRow(phase: phase)
                    }
                }
            }
        }
    }

    private func barColumn(phase: PhaseLine) -> some View {
        let value = ampsByPhase[phase] ?? 0
        let ratio = min(1, value / maxA)
        return VStack(spacing: 6) {
            Text(BalanceCalculator.formatA(value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(PCColor.secondaryText)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PCColor.structure.opacity(0.6))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(barGradient(for: phase, ratio: ratio))
                        .frame(height: max(4, geo.size.height * ratio))
                        .animation(.easeInOut(duration: 0.35), value: ratio)
                }
            }
            .frame(height: 120)
            Text(phase.shortTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PCColor.dataBlue)
        }
        .frame(maxWidth: .infinity)
    }

    private func barRow(phase: PhaseLine) -> some View {
        let value = ampsByPhase[phase] ?? 0
        let ratio = min(1, value / maxA)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phase.shortTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PCColor.dataBlue)
                Spacer()
                Text(BalanceCalculator.formatA(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PCColor.secondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PCColor.structure.opacity(0.6))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(barGradient(for: phase, ratio: ratio))
                        .frame(width: max(4, geo.size.width * ratio))
                        .animation(.easeInOut(duration: 0.35), value: ratio)
                }
            }
            .frame(height: 14)
        }
    }

    private func barGradient(for phase: PhaseLine, ratio: Double) -> LinearGradient {
        let skewed = ratio > 0 && (ampsByPhase[phase] ?? 0) >= maxA * 0.92
        if skewed {
            return PCGradients.orangeYellow
        }
        switch phase {
        case .L1:
            return LinearGradient(colors: [PCColor.dataBlue, PCColor.dataBlue.opacity(0.5)], startPoint: .bottom, endPoint: .top)
        case .L2:
            return PCGradients.indigoBlue
        case .L3:
            return LinearGradient(colors: [PCColor.balance.opacity(0.85), PCColor.dataBlue.opacity(0.6)], startPoint: .bottom, endPoint: .top)
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }
}

struct SectionHeader: View {
    let title: String
    var emoji: String?

    var body: some View {
        HStack(spacing: 8) {
            if let emoji { Text(emoji).font(.title3) }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PCColor.secondaryText)
            Spacer()
        }
        .padding(.top, 4)
    }
}


import Charts
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var showThresholds = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                if let project = store.selectedProject {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            currentVsLimitCard(project)
                            snapshotChart(project)
                            NavigationLink {
                                AnalyticsChartDetailView()
                                    .environmentObject(store)
                            } label: {
                                HStack {
                                    Text("Full-screen charts")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PCColor.dataBlue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PCColor.secondaryText)
                                }
                                .padding(14)
                                .background(PCColor.layer)
                                .clipShape(RoundedRectangle(cornerRadius: PCMetrics.cornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PCMetrics.cornerRadius, style: .continuous)
                                        .stroke(PCColor.structure, lineWidth: PCMetrics.borderWidth)
                                )
                            }
                            .buttonStyle(.plain)
                            warningsBlock(project)
                            HStack(spacing: 10) {
                                PCOutlineButton(title: "Thresholds", color: PCColor.dataBlue) {
                                    showThresholds = true
                                }
                                PCOutlineButton(title: "Snapshot history", color: PCColor.skew) {
                                    showHistory = true
                                }
                            }
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    Text("No project")
                        .foregroundStyle(PCColor.secondaryText)
                }
            }
            .navigationTitle("📊 Analytics")
            .sheet(isPresented: $showThresholds) {
                ThresholdsView().environmentObject(store)
            }
            .sheet(isPresented: $showHistory) {
                SnapshotHistoryView().environmentObject(store)
            }
        }
    }

    private func currentVsLimitCard(_ project: Project) -> some View {
        let report = BalanceCalculator.report(loads: project.loads, context: project.context, thresholds: store.settings.thresholds)
        return PCCard(topAccent: PCColor.dataBlue) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Headroom to limit")
                    .font(.headline)
                    .foregroundStyle(.white)
                if let limit = project.context.maxCurrentPerPhaseAmps, limit > 0 {
                    ForEach(PhaseLine.allCases) { p in
                        let a = report.ampsByPhase[p] ?? 0
                        let pct = min(1.1, a / limit)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(p.shortTitle)
                                Spacer()
                                Text("\(BalanceCalculator.formatA(a)) / \(BalanceCalculator.formatA(limit))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(PCColor.secondaryText)
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(PCColor.structure)
                                    Capsule()
                                        .fill(pct >= 1 ? PCGradients.orangeYellow : PCGradients.greenLime)
                                        .frame(width: min(g.size.width, g.size.width * pct))
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                } else {
                    Text("Set a per-phase current limit in the project settings.")
                        .font(.caption)
                        .foregroundStyle(PCColor.secondaryText)
                }
            }
        }
    }

    private func snapshotChart(_ project: Project) -> some View {
        PCCard(topAccent: PCColor.balance) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Imbalance history")
                    .font(.headline)
                    .foregroundStyle(.white)
                if project.snapshots.isEmpty {
                    Text("Save snapshots on the dashboard — a chart will appear here.")
                        .font(.caption)
                        .foregroundStyle(PCColor.secondaryText)
                } else {
                    let data = Array(project.snapshots.reversed())
                    Chart {
                        ForEach(data) { snap in
                            LineMark(
                                x: .value("Time", snap.createdAt),
                                y: .value("%", snap.imbalancePercent)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(PCGradients.indigoBlue)
                        }
                        RuleMark(y: .value("Yellow", store.settings.thresholds.yellowImbalancePercent))
                            .foregroundStyle(PCColor.skew.opacity(0.35))
                            .lineStyle(StrokeStyle(dash: [4, 4]))
                        RuleMark(y: .value("Red", store.settings.thresholds.redImbalancePercent))
                            .foregroundStyle(PCColor.critical.opacity(0.35))
                            .lineStyle(StrokeStyle(dash: [4, 4]))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private func warningsBlock(_ project: Project) -> some View {
        let report = BalanceCalculator.report(loads: project.loads, context: project.context, thresholds: store.settings.thresholds)
        let maxPhase = PhaseLine.allCases.map { report.ampsByPhase[$0] ?? 0 }.max() ?? 0
        let suggestedBreaker = BalanceCalculator.suggestedBreakerAmps(forPhaseCurrentAmps: maxPhase)
        let suggestedCable = suggestedBreaker.flatMap { BalanceCalculator.suggestedCopperCableMm2(forBreakerAmps: $0) }
        return PCCard(topAccent: PCColor.skew) {
            VStack(alignment: .leading, spacing: 8) {
                Text("⚠️ Risks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PCColor.secondaryText)
                HStack {
                    Text("Neutral: \(BalanceCalculator.formatA(report.neutralCurrentAmps))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PCColor.secondaryText)
                    Spacer()
                    if let suggestedBreaker {
                        Text("Breaker ≈ \(Int(suggestedBreaker)) A")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PCColor.dataBlue)
                    }
                    if let suggestedCable {
                        Text("Cu ≈ \(String(format: "%.1f", suggestedCable)) mm²")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PCColor.secondaryText)
                    }
                }
                if report.warnings.isEmpty {
                    Text("No critical warnings.")
                        .font(.caption)
                        .foregroundStyle(PCColor.secondaryText)
                } else {
                    ForEach(report.warnings, id: \.self) { w in
                        Text("• " + w)
                            .font(.caption)
                            .foregroundStyle(PCColor.skew)
                    }
                }
            }
        }
    }
}

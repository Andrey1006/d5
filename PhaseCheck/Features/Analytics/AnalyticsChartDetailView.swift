
import Charts
import SwiftUI

struct AnalyticsChartDetailView: View {
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        ZStack {
            PCScreenBackground()
            if let project = store.selectedProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PCCard(topAccent: PCColor.dataBlue) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Imbalance from snapshots")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                if project.snapshots.isEmpty {
                                    Text("No snapshots yet.")
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
                                            .foregroundStyle(PCColor.dataBlue)
                                        }
                                        RuleMark(y: .value("Yel.", store.settings.thresholds.yellowImbalancePercent))
                                            .foregroundStyle(PCColor.skew.opacity(0.3))
                                            .lineStyle(StrokeStyle(dash: [4, 4]))
                                        RuleMark(y: .value("Red", store.settings.thresholds.redImbalancePercent))
                                            .foregroundStyle(PCColor.critical.opacity(0.3))
                                            .lineStyle(StrokeStyle(dash: [4, 4]))
                                    }
                                    .chartYAxis { AxisMarks(position: .leading) }
                                    .frame(height: 280)
                                }
                            }
                        }

                        PCCard(topAccent: PCColor.balance) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phase currents (snapshots)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                if project.snapshots.isEmpty {
                                    Text("No snapshots yet.")
                                        .foregroundStyle(PCColor.secondaryText)
                                } else {
                                    let data = Array(project.snapshots.reversed())
                                    Chart {
                                        ForEach(PhaseLine.allCases) { phase in
                                            ForEach(data) { snap in
                                                LineMark(
                                                    x: .value("Time", snap.createdAt),
                                                    y: .value("Current", snap.ampsByPhase[phase] ?? 0),
                                                    series: .value("Phase", phase.rawValue)
                                                )
                                                .interpolationMethod(.catmullRom)
                                                .foregroundStyle(chartColor(for: phase))
                                            }
                                        }
                                    }
                                    .chartLegend(position: .bottom, alignment: .center)
                                    .chartYAxis { AxisMarks(position: .leading) }
                                    .frame(height: 320)
                                }
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
        .navigationTitle("Charts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func chartColor(for phase: PhaseLine) -> Color {
        switch phase {
        case .L1: return PCColor.dataBlue
        case .L2: return PCColor.skew
        case .L3: return PCColor.balance
        }
    }
}

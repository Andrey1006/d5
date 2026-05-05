
import SwiftUI

struct CompareScenariosView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var leftId: UUID?
    @State private var rightId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                if let project = store.selectedProject, !project.scenarios.isEmpty {
                    Form {
                        Section("Scenario A") {
                            Picker("A", selection: $leftId) {
                                Text("—").tag(nil as UUID?)
                                ForEach(project.scenarios) { s in
                                    Text(s.name).tag(Optional(s.id))
                                }
                            }
                        }
                        .listRowBackground(PCColor.layer)

                        Section("Scenario B") {
                            Picker("B", selection: $rightId) {
                                Text("—").tag(nil as UUID?)
                                ForEach(project.scenarios) { s in
                                    Text(s.name).tag(Optional(s.id))
                                }
                            }
                        }
                        .listRowBackground(PCColor.layer)

                        if let a = scenario(project, id: leftId),
                           let b = scenario(project, id: rightId) {
                            Section("Current comparison") {
                                ForEach(PhaseLine.allCases) { p in
                                    HStack {
                                        Text(p.shortTitle)
                                        Spacer()
                                        Text(BalanceCalculator.formatA(a.ampsByPhase[p] ?? 0))
                                            .monospacedDigit()
                                        Text("→")
                                            .foregroundStyle(PCColor.secondaryText)
                                        Text(BalanceCalculator.formatA(b.ampsByPhase[p] ?? 0))
                                            .monospacedDigit()
                                    }
                                    .foregroundStyle(.white)
                                }
                                HStack {
                                    Text("Imbalance")
                                    Spacer()
                                    Text(BalanceCalculator.formatPercent(a.imbalancePercent))
                                    Text("vs")
                                        .foregroundStyle(PCColor.secondaryText)
                                    Text(BalanceCalculator.formatPercent(b.imbalancePercent))
                                }
                                .foregroundStyle(.white)
                            }
                            .listRowBackground(PCColor.layer)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        if leftId == nil { leftId = project.scenarios.first?.id }
                        if rightId == nil { rightId = project.scenarios.dropFirst().first?.id ?? project.scenarios.first?.id }
                    }
                } else {
                    Text("You need at least one saved scenario.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PCColor.secondaryText)
                        .padding()
                }
            }
            .navigationTitle("Compare")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func scenario(_ project: Project, id: UUID?) -> SavedScenario? {
        guard let id else { return nil }
        return project.scenarios.first { $0.id == id }
    }
}

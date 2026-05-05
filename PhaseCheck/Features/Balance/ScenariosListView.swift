
import SwiftUI

struct ScenariosListView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: SavedScenario?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                if let project = store.selectedProject {
                    List {
                        ForEach(project.scenarios) { s in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(s.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(BalanceCalculator.formatPercent(s.imbalancePercent))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(PCColor.secondaryText)
                                }
                                Text(s.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(PCColor.secondaryText)
                                HStack(spacing: 8) {
                                    Button("Apply") {
                                        store.applyScenarioToProject(s)
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(PCColor.balance.opacity(0.35))

                                    Button("Rename") {
                                        renaming = s
                                        renameText = s.name
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(PCColor.dataBlue.opacity(0.4))

                                    Spacer()
                                    Button(role: .destructive) {
                                        store.deleteScenario(id: s.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .listRowBackground(PCColor.layer)
                        }
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    Text("No project")
                        .foregroundStyle(PCColor.secondaryText)
                }
            }
            .navigationTitle("Scenarios")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $renaming) { scenario in
                NavigationStack {
                    ZStack {
                        PCScreenBackground()
                        Form {
                            TextField("Name", text: $renameText)
                                .listRowBackground(PCColor.layer)
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .navigationTitle("Scenario")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { renaming = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.renameScenario(scenarioId: scenario.id, name: renameText)
                                renaming = nil
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

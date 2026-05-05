
import SwiftUI

struct BalanceView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var draftPhase: [UUID: PhaseLine] = [:]
    @State private var scenarioName = ""
    @State private var showSaveScenario = false
    @State private var showScenarios = false
    @State private var showCompare = false

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                if let project = store.selectedProject {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            reportCard(project)
                            PhaseBarsView(ampsByPhase: report(project).ampsByPhase, maxScale: project.context.maxCurrentPerPhaseAmps, orientation: .vertical)
                            loadsDraftList(project)
                            actionsBlock
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear { syncDraft(from: project) }
                    .onChange(of: store.selectedProject) { new in
                        if let p = new { syncDraft(from: p) }
                    }
                } else {
                    Text("No project")
                        .foregroundStyle(PCColor.secondaryText)
                }
            }
            .navigationTitle("⚖️ Balance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScenarios = true } label: {
                        Image(systemName: "square.stack.3d.forward.dots")
                            .foregroundStyle(PCColor.dataBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCompare = true } label: {
                        Image(systemName: "arrow.left.arrow.right.square")
                            .foregroundStyle(PCColor.skew)
                    }
                }
            }
            .sheet(isPresented: $showSaveScenario) {
                NavigationStack {
                    Form {
                        TextField("Scenario name", text: $scenarioName)
                    }
                    .navigationTitle("Save scenario")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSaveScenario = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.addScenario(name: scenarioName.isEmpty ? "Scenario" : scenarioName, phaseByLoadId: draftPhase)
                                scenarioName = ""
                                showSaveScenario = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showScenarios) {
                ScenariosListView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCompare) {
                CompareScenariosView()
                    .environmentObject(store)
            }
        }
    }

    private func syncDraft(from project: Project) {
        draftPhase = Dictionary(uniqueKeysWithValues: project.loads.map { ($0.id, $0.phase) })
    }

    private func report(_ project: Project) -> BalanceReport {
        BalanceCalculator.report(
            loads: project.loads,
            context: project.context,
            thresholds: store.settings.thresholds,
            phaseOverride: { draftPhase[$0] }
        )
    }

    @ViewBuilder
    private func reportCard(_ project: Project) -> some View {
        let r = report(project)
        PCCard(topAccent: PCColor.status(r.status)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Simulation")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    StatusPill(text: statusTitle(r.status), color: PCColor.status(r.status))
                }
                Text("Imbalance: \(BalanceCalculator.formatPercent(r.imbalancePercent))")
                    .foregroundStyle(PCColor.secondaryText)
                if !r.warnings.isEmpty {
                    ForEach(r.warnings, id: \.self) { w in
                        Text("⚠️ " + w)
                            .font(.caption)
                            .foregroundStyle(PCColor.skew)
                    }
                }
            }
        }
    }

    private func loadsDraftList(_ project: Project) -> some View {
        PCCard(topAccent: PCColor.dataBlue) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Redistribution")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PCColor.secondaryText)
                ForEach(project.loads) { load in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(load.name)
                                .foregroundStyle(.white)
                            Text(BalanceCalculator.formatA(BalanceCalculator.resolvedLineCurrentAmps(for: load, context: project.context)))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(PCColor.secondaryText)
                            Text(load.connectionKind.shortTitle)
                                .font(.caption2)
                                .foregroundStyle(PCColor.secondaryText.opacity(0.85))
                        }
                        Spacer()
                        if load.connectionKind == .singlePhase {
                            Picker("", selection: bindingPhase(for: load.id)) {
                                ForEach(PhaseLine.allCases) { p in
                                    Text(p.shortTitle).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(PCColor.dataBlue)
                        } else {
                            Text("L1–L3")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PCColor.dataBlue.opacity(0.85))
                        }
                    }
                    Divider().background(PCColor.structure)
                }
            }
        }
    }

    private func bindingPhase(for id: UUID) -> Binding<PhaseLine> {
        Binding(
            get: { draftPhase[id] ?? .L1 },
            set: { draftPhase[id] = $0 }
        )
    }

    private var actionsBlock: some View {
        VStack(spacing: 10) {
            PCGradientButton(title: "Auto-balance (suggestion)") {
                guard let project = store.selectedProject else { return }
                draftPhase = BalanceCalculator.suggestedPhases(loads: project.loads, context: project.context)
            }
            PCOutlineButton(title: "Apply phases to project", color: PCColor.balance) {
                guard let project = store.selectedProject else { return }
                var updated = project
                for i in updated.loads.indices {
                    guard updated.loads[i].connectionKind == .singlePhase else { continue }
                    if let ph = draftPhase[updated.loads[i].id] {
                        updated.loads[i].phase = ph
                    }
                }
                store.upsertProject(updated)
            }
            PCOutlineButton(title: "Save as scenario", color: PCColor.dataBlue) {
                showSaveScenario = true
            }
            PCOutlineButton(title: "Reset draft", color: PCColor.secondaryText) {
                if let project = store.selectedProject { syncDraft(from: project) }
            }
        }
    }

    private func statusTitle(_ s: BalanceStatus) -> String {
        switch s {
        case .balanced: return "OK"
        case .skewed: return "Skewed"
        case .critical: return "Risk"
        }
    }
}

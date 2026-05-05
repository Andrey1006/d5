
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var showProjectPicker = false
    @State private var showSnapshotSheet = false
    @State private var snapshotNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let project = store.selectedProject {
                            projectHeader(project)
                            balanceCard(project)
                            quickActions
                        } else {
                            emptyState
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("⚡ Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProjectPicker = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundStyle(PCColor.dataBlue)
                    }
                }
            }
            .sheet(isPresented: $showProjectPicker) {
                ProjectPickerSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSnapshotSheet) {
                NavigationStack {
                    Form {
                        TextField("Snapshot note", text: $snapshotNote)
                    }
                    .navigationTitle("Balance snapshot")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSnapshotSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.addSnapshot(note: snapshotNote)
                                snapshotNote = ""
                                showSnapshotSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private func projectHeader(_ project: Project) -> some View {
        PCCard(topAccent: PCColor.dataBlue) {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(project.context.gridLabel)
                    .font(.caption)
                    .foregroundStyle(PCColor.secondaryText)
                HStack {
                    Label("U_LN \(Int(project.context.lineToNeutralVoltageVolts)) V", systemImage: "waveform.path.ecg")
                    Spacer()
                    Label("cos φ \(String(format: "%.2f", project.context.defaultPowerFactor))", systemImage: "slider.horizontal.2.square")
                }
                .font(.caption2)
                .foregroundStyle(PCColor.secondaryText)
            }
        }
    }

    @ViewBuilder
    private func balanceCard(_ project: Project) -> some View {
        let report = BalanceCalculator.report(loads: project.loads, context: project.context, thresholds: store.settings.thresholds)
        PCCard(topAccent: PCColor.status(report.status)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("📊 Phase balance")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    statusView(report.status, imbalance: report.imbalancePercent)
                }
                PhaseBarsView(
                    ampsByPhase: report.ampsByPhase,
                    maxScale: project.context.maxCurrentPerPhaseAmps,
                    orientation: .horizontal
                )
                Text("Imbalance: \(BalanceCalculator.formatPercent(report.imbalancePercent))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(PCColor.secondaryText)
                if !report.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.warnings, id: \.self) { w in
                            Label(w, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(PCColor.skew)
                        }
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Actions", emoji: "🔌")
            PCGradientButton(title: "Save balance snapshot") {
                showSnapshotSheet = true
            }
            HStack(spacing: 10) {
                PCOutlineButton(title: "Loads", color: PCColor.dataBlue) {
                    store.selectedMainTab = .loads
                }
                PCOutlineButton(title: "Balance", color: PCColor.balance) {
                    store.selectedMainTab = .balance
                }
                PCOutlineButton(title: "Analytics", color: PCColor.skew) {
                    store.selectedMainTab = .analytics
                }
            }
        }
    }

    private var emptyState: some View {
        PCCard(topAccent: PCColor.skew) {
            Text("No active project. Create one in the Projects tab.")
                .foregroundStyle(PCColor.secondaryText)
        }
    }

    private func statusView(_ status: BalanceStatus, imbalance: Double) -> some View {
        let text: String
        switch status {
        case .balanced: text = "OK"
        case .skewed: text = "Skewed"
        case .critical: text = "Risk"
        }
        return VStack(alignment: .trailing, spacing: 4) {
            StatusPill(text: text, color: PCColor.status(status))
            Text(BalanceCalculator.formatPercent(imbalance))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(PCColor.secondaryText)
        }
    }
}

struct ProjectPickerSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                List {
                    ForEach(store.projects) { p in
                        Button {
                            store.selectProject(p.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.name).foregroundStyle(.white)
                                    Text(p.context.gridLabel)
                                        .font(.caption)
                                        .foregroundStyle(PCColor.secondaryText)
                                }
                                Spacer()
                                if store.selectedProjectId == p.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PCColor.balance)
                                }
                            }
                        }
                        .listRowBackground(PCColor.layer)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

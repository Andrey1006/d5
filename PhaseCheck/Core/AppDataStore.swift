
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDataStore: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published var selectedProjectId: UUID?
    @Published var settings: AppSettings
    @Published var templates: [LoadTemplate] = []
    @Published var selectedMainTab: MainTab = .dashboard

    init() {
        if let saved = PersistenceService.load() {
            projects = saved.projects
            selectedProjectId = saved.selectedProjectId
            settings = saved.settings
            templates = saved.templates.isEmpty ? Self.defaultTemplates : saved.templates
            if projects.isEmpty {
                let starter = Self.makeStarterProject()
                projects = [starter]
                selectedProjectId = starter.id
            }
        } else {
            settings = AppSettings(
                preferPowerInsteadOfCurrent: false,
                thresholds: ThresholdSettings(
                    yellowImbalancePercent: 15,
                    redImbalancePercent: 30,
                    criticalCurrentPercentOfLimit: 90
                )
            )
            templates = Self.defaultTemplates
            let starter = Self.makeStarterProject()
            projects = [starter]
            selectedProjectId = starter.id
            persist()
        }
        if selectedProjectId == nil {
            selectedProjectId = projects.first?.id
        }
    }

    var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return projects.first { $0.id == id }
    }

    func selectProject(_ id: UUID?) {
        selectedProjectId = id
        persist()
    }

    func upsertProject(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            projects.append(project)
        }
        persist()
    }

    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        if selectedProjectId == id {
            selectedProjectId = projects.first?.id
        }
        persist()
    }

    func updateSettings(_ new: AppSettings) {
        settings = new
        persist()
    }

    func replaceAllFromImport(_ payload: PersistedPayload) {
        projects = payload.projects
        selectedProjectId = payload.selectedProjectId ?? projects.first?.id
        settings = payload.settings
        templates = payload.templates
        persist()
    }

    func mutateSelected(_ body: (inout Project) -> Void) {
        guard let id = selectedProjectId, let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        body(&projects[idx])
        persist()
    }

    func addLoad(_ load: LoadDevice) {
        mutateSelected { $0.loads.append(load) }
    }

    func updateLoad(_ load: LoadDevice) {
        mutateSelected { p in
            if let i = p.loads.firstIndex(where: { $0.id == load.id }) {
                p.loads[i] = load
            }
        }
    }

    func deleteLoad(id: UUID) {
        mutateSelected { p in
            p.loads.removeAll { $0.id == id }
            p.scenarios = p.scenarios.map { s in
                var c = s
                c.phaseByLoadId.removeValue(forKey: id)
                return c
            }
        }
    }

    func bulkDeleteLoads(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        mutateSelected { p in
            p.loads.removeAll { ids.contains($0.id) }
            p.scenarios = p.scenarios.map { s in
                var c = s
                for id in ids { c.phaseByLoadId.removeValue(forKey: id) }
                return c
            }
        }
    }

    func bulkAssignPhase(ids: Set<UUID>, phase: PhaseLine) {
        guard !ids.isEmpty else { return }
        mutateSelected { p in
            for i in p.loads.indices where ids.contains(p.loads[i].id) {
                if p.loads[i].connectionKind == .singlePhase {
                    p.loads[i].phase = phase
                }
            }
        }
    }

    func duplicateLoads(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        mutateSelected { p in
            for id in ids {
                guard let l = p.loads.first(where: { $0.id == id }) else { continue }
                var c = l
                c.id = UUID()
                c.name = InputValidation.sanitizedName(l.name, fallback: "Load") + " (copy)"
                p.loads.append(c)
            }
        }
    }

    func addSnapshot(note: String) {
        guard var p = selectedProject else { return }
        let report = BalanceCalculator.report(loads: p.loads, context: p.context, thresholds: settings.thresholds)
        let snap = BalanceSnapshot(
            id: UUID(),
            createdAt: Date(),
            note: note,
            ampsByPhase: report.ampsByPhase,
            imbalancePercent: report.imbalancePercent,
            statusToken: String(describing: report.status)
        )
        p.snapshots.insert(snap, at: 0)
        upsertProject(p)
    }

    func updateSnapshotNote(snapshotId: UUID, note: String) {
        mutateSelected { p in
            if let i = p.snapshots.firstIndex(where: { $0.id == snapshotId }) {
                p.snapshots[i].note = note
            }
        }
    }

    func addScenario(name: String, phaseByLoadId: [UUID: PhaseLine]) {
        guard var p = selectedProject else { return }
        let report = BalanceCalculator.report(
            loads: p.loads,
            context: p.context,
            thresholds: settings.thresholds,
            phaseOverride: { phaseByLoadId[$0] }
        )
        let scenario = SavedScenario(
            id: UUID(),
            name: name,
            createdAt: Date(),
            phaseByLoadId: phaseByLoadId,
            ampsByPhase: report.ampsByPhase,
            imbalancePercent: report.imbalancePercent
        )
        p.scenarios.insert(scenario, at: 0)
        upsertProject(p)
    }

    func renameScenario(scenarioId: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutateSelected { p in
            if let i = p.scenarios.firstIndex(where: { $0.id == scenarioId }) {
                p.scenarios[i].name = trimmed
            }
        }
    }

    func applyScenarioToProject(_ scenario: SavedScenario) {
        mutateSelected { p in
            for i in p.loads.indices {
                guard p.loads[i].connectionKind == .singlePhase else { continue }
                if let ph = scenario.phaseByLoadId[p.loads[i].id] {
                    p.loads[i].phase = ph
                }
            }
        }
    }

    func deleteScenario(id: UUID) {
        mutateSelected { $0.scenarios.removeAll { $0.id == id } }
    }

    func deleteSnapshot(id: UUID) {
        mutateSelected { $0.snapshots.removeAll { $0.id == id } }
    }

    func upsertTemplate(_ t: LoadTemplate) {
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates[i] = t
        } else {
            templates.append(t)
        }
        persist()
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        persist()
    }

    func exportPayload() -> PersistedPayload {
        PersistedPayload(projects: projects, selectedProjectId: selectedProjectId, settings: settings, templates: templates)
    }

    func persist() {
        PersistenceService.save(exportPayload())
    }

    private static func makeStarterProject() -> Project {
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

    private static var defaultTemplates: [LoadTemplate] {
        [
            LoadTemplate(id: UUID(), name: "Cooktop", category: .kitchen, defaultInputKind: .power, defaultCurrentAmps: 0, defaultPowerKW: 7, connectionKind: .threePhaseBalanced, customPowerFactor: nil),
            LoadTemplate(id: UUID(), name: "Oven", category: .kitchen, defaultInputKind: .power, defaultCurrentAmps: 0, defaultPowerKW: 3.5, connectionKind: .singlePhase, customPowerFactor: nil),
            LoadTemplate(id: UUID(), name: "Air conditioner", category: .hvac, defaultInputKind: .current, defaultCurrentAmps: 8, defaultPowerKW: 0, connectionKind: .singlePhase, customPowerFactor: nil),
            LoadTemplate(id: UUID(), name: "Living room lighting", category: .lighting, defaultInputKind: .power, defaultCurrentAmps: 0, defaultPowerKW: 0.4, connectionKind: .singlePhase, customPowerFactor: nil)
        ]
    }
}

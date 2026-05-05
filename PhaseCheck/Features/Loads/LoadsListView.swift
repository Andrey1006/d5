
import SwiftUI

private enum LoadSort: String, CaseIterable, Identifiable {
    case name, currentDesc, phase, category
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return "By name"
        case .currentDesc: return "By current ↓"
        case .phase: return "By phase"
        case .category: return "By category"
        }
    }
}

struct LoadsListView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var filterPhase: PhaseLine?
    @State private var filterCategory: LoadCategory?
    @State private var sort: LoadSort = .name
    @State private var searchText = ""
    @State private var bulkMode = false
    @State private var bulkSelection: Set<UUID> = []
    @State private var showTemplates = false
    @State private var showEditor: LoadDevice?
    @State private var showBulkPhasePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                if let project = store.selectedProject {
                    List {
                        Section {
                            phaseFilterChips
                            categoryFilterChips
                        }
                        .listRowBackground(Color.clear)

                        if displayLoads(project).isEmpty {
                            Text("No loads yet. Add a device or apply a template.")
                                .font(.subheadline)
                                .foregroundStyle(PCColor.secondaryText)
                                .listRowBackground(PCColor.layer)
                        } else {
                            ForEach(displayLoads(project)) { load in
                                if bulkMode {
                                    Button {
                                        toggleBulk(load.id)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: bulkSelection.contains(load.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(bulkSelection.contains(load.id) ? PCColor.dataBlue : PCColor.secondaryText)
                                            loadRow(load, context: project.context)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(PCColor.layer)
                                } else {
                                    NavigationLink(value: load.id) {
                                        loadRow(load, context: project.context)
                                    }
                                    .listRowBackground(PCColor.layer)
                                }
                            }
                            .onDelete { indexSet in
                                let ids = indexSet.map { displayLoads(project)[$0].id }
                                ids.forEach { store.deleteLoad(id: $0) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .navigationDestination(for: UUID.self) { id in
                        if let load = project.loads.first(where: { $0.id == id }) {
                            LoadEditorView(mode: .edit(load))
                                .environmentObject(store)
                        }
                    }
                } else {
                    Text("Select a project on the dashboard or in the Projects tab.")
                        .foregroundStyle(PCColor.secondaryText)
                        .padding()
                }
            }
            .navigationTitle("🔌 Loads")
            .searchable(text: $searchText, prompt: "Search by name")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Button { showTemplates = true } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(PCColor.skew)
                        }
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(LoadSort.allCases) { s in
                                    Text(s.title).tag(s)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .foregroundStyle(PCColor.secondaryText)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            bulkMode.toggle()
                            if !bulkMode { bulkSelection.removeAll() }
                        } label: {
                            Text(bulkMode ? "Done" : "Select")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PCColor.dataBlue)
                        }
                        if bulkMode {
                            Menu("Actions") {
                                Button("Move to L1") { assignBulk(.L1) }
                                Button("Move to L2") { assignBulk(.L2) }
                                Button("Move to L3") { assignBulk(.L3) }
                                Divider()
                                Button("Duplicate") { duplicateBulk() }
                                Button("Delete", role: .destructive) { deleteBulk() }
                                Divider()
                                Button("Select visible") { selectAllVisible() }
                                Button("Clear selection") { bulkSelection.removeAll() }
                            }
                        }
                        Button {
                            showEditor = newDraftLoad()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(PCColor.dataBlue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showTemplates) {
                TemplatePickerSheet { tpl in
                    store.addLoad(deviceFromTemplate(tpl))
                    showTemplates = false
                }
                .environmentObject(store)
            }
            .sheet(item: $showEditor) { load in
                NavigationStack {
                    LoadEditorView(mode: .create(load))
                        .environmentObject(store)
                }
            }
        }
    }

    private func toggleBulk(_ id: UUID) {
        if bulkSelection.contains(id) {
            bulkSelection.remove(id)
        } else {
            bulkSelection.insert(id)
        }
    }

    private func selectAllVisible() {
        guard let project = store.selectedProject else { return }
        bulkSelection = Set(displayLoads(project).map(\.id))
    }

    private func assignBulk(_ phase: PhaseLine) {
        store.bulkAssignPhase(ids: bulkSelection, phase: phase)
    }

    private func duplicateBulk() {
        store.duplicateLoads(ids: Array(bulkSelection))
    }

    private func deleteBulk() {
        store.bulkDeleteLoads(ids: bulkSelection)
        bulkSelection.removeAll()
    }

    private var phaseFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All phases", selected: filterPhase == nil) { filterPhase = nil }
                ForEach(PhaseLine.allCases) { p in
                    chip(p.shortTitle, selected: filterPhase == p) { filterPhase = p }
                }
            }
        }
    }

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All types", selected: filterCategory == nil) { filterCategory = nil }
                ForEach(LoadCategory.allCases, id: \.self) { c in
                    chip(c.title, selected: filterCategory == c) { filterCategory = c }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? PCColor.dataBlue.opacity(0.35) : PCColor.structure.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: PCMetrics.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PCMetrics.cornerRadiusSmall, style: .continuous)
                        .stroke(selected ? PCColor.dataBlue : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func displayLoads(_ project: Project) -> [LoadDevice] {
        var list = filteredLoads(project)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }
        switch sort {
        case .name:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .currentDesc:
            list.sort {
                BalanceCalculator.resolvedLineCurrentAmps(for: $0, context: project.context) >
                    BalanceCalculator.resolvedLineCurrentAmps(for: $1, context: project.context)
            }
        case .phase:
            list.sort { $0.phase.rawValue < $1.phase.rawValue }
        case .category:
            list.sort { $0.category.title < $1.category.title }
        }
        return list
    }

    private func filteredLoads(_ project: Project) -> [LoadDevice] {
        var list = project.loads
        if let cat = filterCategory {
            list = list.filter { $0.category == cat }
        }
        if let f = filterPhase {
            list = list.filter { load in
                if load.connectionKind == .threePhaseBalanced { return true }
                return load.phase == f
            }
        }
        return list
    }

    private func loadRow(_ load: LoadDevice, context: ProjectElectricalContext) -> some View {
        let a = BalanceCalculator.resolvedLineCurrentAmps(for: load, context: context)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(load.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(load.category.title)
                        .font(.caption)
                        .foregroundStyle(PCColor.secondaryText)
                    Text(load.connectionKind.shortTitle)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PCColor.structure.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(PCColor.secondaryText)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(load.connectionKind == .threePhaseBalanced ? "L1–L3" : load.phase.shortTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PCColor.dataBlue)
                Text(BalanceCalculator.formatA(a))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PCColor.secondaryText)
            }
        }
        .opacity(load.isIncluded ? 1 : 0.45)
    }

    private func newDraftLoad() -> LoadDevice {
        LoadDevice(
            id: UUID(),
            name: "New load",
            category: .other,
            phase: .L1,
            isIncluded: true,
            inputKind: store.settings.preferPowerInsteadOfCurrent ? .power : .current,
            currentAmps: 0,
            powerKW: 0,
            connectionKind: .singlePhase,
            customPowerFactor: nil
        )
    }

    private func deviceFromTemplate(_ t: LoadTemplate) -> LoadDevice {
        LoadDevice(
            id: UUID(),
            name: t.name,
            category: t.category,
            phase: .L1,
            isIncluded: true,
            inputKind: t.defaultInputKind,
            currentAmps: t.defaultCurrentAmps,
            powerKW: t.defaultPowerKW,
            connectionKind: t.connectionKind,
            customPowerFactor: t.customPowerFactor
        )
    }
}

struct TemplatePickerSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var onPick: (LoadTemplate) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                List(store.templates) { t in
                    Button {
                        onPick(t)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.name).foregroundStyle(.white)
                            Text("\(t.category.title) · \(t.connectionKind.shortTitle)")
                                .font(.caption)
                                .foregroundStyle(PCColor.secondaryText)
                        }
                    }
                    .listRowBackground(PCColor.layer)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}


import SwiftUI

enum LoadEditorMode: Equatable {
    case create(LoadDevice)
    case edit(LoadDevice)
}

struct LoadEditorView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    let mode: LoadEditorMode
    @State private var draft: LoadDevice
    @State private var tagsField: String = ""
    @State private var useCustomCos: Bool = false
    @State private var validationMessage: String?

    init(mode: LoadEditorMode) {
        self.mode = mode
        switch mode {
        case let .create(d), let .edit(d):
            _draft = State(initialValue: d)
            _useCustomCos = State(initialValue: d.customPowerFactor != nil)
        }
    }

    var body: some View {
        ZStack {
            PCScreenBackground()
            Form {
                Section("Device") {
                    TextField("Name", text: $draft.name)
                    Picker("Category", selection: $draft.category) {
                        ForEach(LoadCategory.allCases, id: \.self) { c in
                            Text(c.title).tag(c)
                        }
                    }
                    Picker("Connection", selection: $draft.connectionKind) {
                        Text("Single phase").tag(LoadConnectionKind.singlePhase)
                        Text("Three-phase balanced").tag(LoadConnectionKind.threePhaseBalanced)
                    }
                    if draft.connectionKind == .singlePhase {
                        Picker("Phase", selection: $draft.phase) {
                            ForEach(PhaseLine.allCases) { p in
                                Text(p.shortTitle).tag(p)
                            }
                        }
                    } else {
                        Text("Evenly on L1, L2, L3. Power uses line-to-line voltage.")
                            .font(.caption)
                            .foregroundStyle(PCColor.secondaryText)
                    }
                    Toggle("Include in calculation", isOn: $draft.isIncluded)
                }
                .listRowBackground(PCColor.layer)

                Section("Tags & priority") {
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(LoadPriority.allCases, id: \.self) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    TextField("Tags (comma-separated)", text: $tagsField, axis: .vertical)
                        .lineLimit(2...4)
                    Text("Use short labels (e.g. fixed, kitchen). Shown in the loads list and PDF.")
                        .font(.caption2)
                        .foregroundStyle(PCColor.secondaryText)
                }
                .listRowBackground(PCColor.layer)

                Section("Input") {
                    Picker("Value type", selection: $draft.inputKind) {
                        Text("Current (A)").tag(LoadInputKind.current)
                        Text("Power (kW)").tag(LoadInputKind.power)
                    }
                    .pickerStyle(.segmented)
                    if draft.inputKind == .current {
                        HStack {
                            Text(draft.connectionKind == .threePhaseBalanced ? "Line current, A" : "Current, A")
                            Spacer()
                            TextField("0", value: $draft.currentAmps, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                    } else {
                        HStack {
                            Text("Power, kW")
                            Spacer()
                            TextField("0", value: $draft.powerKW, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                    }
                }
                .listRowBackground(PCColor.layer)

                Section("cos φ") {
                    Toggle("Custom cos φ for this device", isOn: $useCustomCos)
                        .onChange(of: useCustomCos) { newOn in
                            if !newOn { draft.customPowerFactor = nil }
                            else if draft.customPowerFactor == nil, let p = store.selectedProject {
                                draft.customPowerFactor = p.context.defaultPowerFactor
                            }
                        }
                    if useCustomCos {
                        HStack {
                            Text("cos φ")
                            Spacer()
                            TextField("0.92", value: Binding(
                                get: { draft.customPowerFactor ?? store.selectedProject?.context.defaultPowerFactor ?? 0.92 },
                                set: { draft.customPowerFactor = $0 }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        }
                    } else {
                        Text("Using the project cos φ.")
                            .font(.caption)
                            .foregroundStyle(PCColor.secondaryText)
                    }
                }
                .listRowBackground(PCColor.layer)

                if let project = store.selectedProject {
                    Section("Calculated current") {
                        let a = BalanceCalculator.resolvedLineCurrentAmps(for: draft, context: project.context)
                        Text(BalanceCalculator.formatA(a))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(PCColor.dataBlue)
                        Text(draft.connectionKind == .threePhaseBalanced ? "Per phase (line current)." : "On the selected phase.")
                            .font(.caption2)
                            .foregroundStyle(PCColor.secondaryText)
                    }
                    .listRowBackground(PCColor.layer)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(title)
        .onAppear {
            useCustomCos = draft.customPowerFactor != nil
            tagsField = draft.tags.joined(separator: ", ")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .alert("Validation", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New load"
        case .edit: return "Edit"
        }
    }

    private func save() {
        guard let project = store.selectedProject else {
            validationMessage = "No active project."
            return
        }
        if !useCustomCos {
            draft.customPowerFactor = nil
        }
        draft.name = InputValidation.sanitizedName(draft.name, fallback: "Load")
        draft.tags = InputValidation.normalizeTags(from: tagsField)
        if let err = InputValidation.validate(load: draft, context: project.context) {
            validationMessage = err
            return
        }
        switch mode {
        case .create:
            store.addLoad(draft)
        case .edit:
            store.updateLoad(draft)
        }
        dismiss()
    }
}

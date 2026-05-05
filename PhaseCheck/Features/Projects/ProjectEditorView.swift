
import SwiftUI

struct ProjectEditorView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Project
    private let isNew: Bool
    @State private var validationMessage: String?

    init(project: Project, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: project)
    }

    var body: some View {
        ZStack {
            PCScreenBackground()
            Form {
                Section("Project") {
                    TextField("Name", text: $draft.name)
                    TextField("Supply (label)", text: $draft.context.gridLabel)
                }
                .listRowBackground(PCColor.layer)

                Section("Parameters") {
                    HStack {
                        Text("U line, V")
                        Spacer()
                        TextField("400", value: $draft.context.lineToLineVoltageVolts, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    HStack {
                        Text("U L-N, V")
                        Spacer()
                        TextField("230", value: $draft.context.lineToNeutralVoltageVolts, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    HStack {
                        Text("cos φ")
                        Spacer()
                        TextField("0.92", value: $draft.context.defaultPowerFactor, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    Toggle("Per-phase current limit", isOn: Binding(
                        get: { draft.context.maxCurrentPerPhaseAmps != nil },
                        set: { on in
                            draft.context.maxCurrentPerPhaseAmps = on ? (draft.context.maxCurrentPerPhaseAmps ?? 25) : nil
                        }
                    ))
                    if draft.context.maxCurrentPerPhaseAmps != nil {
                        HStack {
                            Text("Limit, A")
                            Spacer()
                            TextField("25", value: Binding(
                                get: { draft.context.maxCurrentPerPhaseAmps ?? 0 },
                                set: { draft.context.maxCurrentPerPhaseAmps = $0 }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        }
                    }
                }
                .listRowBackground(PCColor.layer)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(isNew ? "New project" : "Project")
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

    private func save() {
        draft.name = InputValidation.sanitizedName(draft.name, fallback: "Project")
        if let err = InputValidation.validate(project: draft) {
            validationMessage = err
            return
        }
        store.upsertProject(draft)
        if isNew { store.selectProject(draft.id) }
        dismiss()
    }
}

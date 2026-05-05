
import SwiftUI

struct TemplatesAdminView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var editing: LoadTemplate?

    var body: some View {
        ZStack {
            PCScreenBackground()
            List {
                ForEach(store.templates) { t in
                    Button {
                        editing = t
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.name).foregroundStyle(.white)
                            Text("\(t.category.title) · \(t.connectionKind.shortTitle)")
                                .font(.caption)
                                .foregroundStyle(PCColor.secondaryText)
                        }
                    }
                    .listRowBackground(PCColor.layer)
                    .swipeActions {
                        Button(role: .destructive) {
                            store.deleteTemplate(id: t.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = LoadTemplate(
                        id: UUID(),
                        name: "Template",
                        category: .other,
                        defaultInputKind: .current,
                        defaultCurrentAmps: 10,
                        defaultPowerKW: 0,
                        connectionKind: .singlePhase,
                        customPowerFactor: nil
                    )
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(PCColor.dataBlue)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editing) { tpl in
            NavigationStack {
                TemplateFormView(template: tpl)
                    .environmentObject(store)
            }
        }
    }
}

private struct TemplateFormView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LoadTemplate
    @State private var useCustomCos = false

    init(template: LoadTemplate) {
        _draft = State(initialValue: template)
        _useCustomCos = State(initialValue: template.customPowerFactor != nil)
    }

    var body: some View {
        ZStack {
            PCScreenBackground()
            Form {
                Section {
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
                    Picker("Type", selection: $draft.defaultInputKind) {
                        Text("Current").tag(LoadInputKind.current)
                        Text("Power").tag(LoadInputKind.power)
                    }
                    .pickerStyle(.segmented)
                    if draft.defaultInputKind == .current {
                        HStack {
                            Text("Current, A")
                            Spacer()
                            TextField("0", value: $draft.defaultCurrentAmps, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                    } else {
                        HStack {
                            Text("kW")
                            Spacer()
                            TextField("0", value: $draft.defaultPowerKW, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                    }
                }
                .listRowBackground(PCColor.layer)

                Section("cos φ in template") {
                    Toggle("Use custom cos φ", isOn: $useCustomCos)
                        .onChange(of: useCustomCos) { newOn in
                            if !newOn { draft.customPowerFactor = nil }
                            else if draft.customPowerFactor == nil { draft.customPowerFactor = 0.92 }
                        }
                    if useCustomCos {
                        HStack {
                            Text("cos φ")
                            Spacer()
                            TextField("0.92", value: Binding(
                                get: { draft.customPowerFactor ?? 0.92 },
                                set: { draft.customPowerFactor = $0 }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        }
                    }
                }
                .listRowBackground(PCColor.layer)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Template")
        .onAppear {
            useCustomCos = draft.customPowerFactor != nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if !useCustomCos { draft.customPowerFactor = nil }
                    store.upsertTemplate(draft)
                    dismiss()
                }
            }
        }
    }
}

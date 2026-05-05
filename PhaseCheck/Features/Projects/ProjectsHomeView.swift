
import SwiftUI

struct ProjectsHomeView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var showNewProject = false
    @State private var showExportImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                List {
                    Section {
                        Button {
                            showNewProject = true
                        } label: {
                            Label("New project", systemImage: "plus.rectangle.fill.on.rectangle.fill")
                                .foregroundStyle(PCColor.balance)
                        }
                        .listRowBackground(PCColor.layer)
                    }

                    Section("Projects") {
                        ForEach(store.projects) { p in
                            NavigationLink {
                                ProjectEditorView(project: p, isNew: false)
                                    .environmentObject(store)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(p.name)
                                            .foregroundStyle(.white)
                                        Text("\(p.loads.count) loads · \(p.context.gridLabel)")
                                            .font(.caption)
                                            .foregroundStyle(PCColor.secondaryText)
                                    }
                                    Spacer()
                                    if store.selectedProjectId == p.id {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(PCColor.dataBlue)
                                    }
                                }
                            }
                            .listRowBackground(PCColor.layer)
                            .contextMenu {
                                Button("Make active") {
                                    store.selectProject(p.id)
                                }
                                Button(role: .destructive) {
                                    store.deleteProject(p.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Section("Tools") {
                        NavigationLink {
                            AppSettingsView().environmentObject(store)
                        } label: {
                            Label("Input settings", systemImage: "gearshape.2")
                        }
                        .listRowBackground(PCColor.layer)

                        NavigationLink {
                            TemplatesAdminView().environmentObject(store)
                        } label: {
                            Label("Load templates", systemImage: "doc.text")
                        }
                        .listRowBackground(PCColor.layer)

                        Button {
                            showExportImport = true
                        } label: {
                            Label("Export / import", systemImage: "arrow.up.arrow.down.circle")
                                .foregroundStyle(PCColor.dataBlue)
                        }
                        .listRowBackground(PCColor.layer)

                        NavigationLink {
                            HelpDisclaimerView()
                        } label: {
                            Label("Help & disclaimer", systemImage: "info.circle")
                        }
                        .listRowBackground(PCColor.layer)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("📁 Projects")
            .sheet(isPresented: $showNewProject) {
                NavigationStack {
                    ProjectEditorView(project: Project.newDraft(), isNew: true)
                        .environmentObject(store)
                }
            }
            .sheet(isPresented: $showExportImport) {
                ExportImportView()
                    .environmentObject(store)
            }
        }
    }
}

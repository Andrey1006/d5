
import SwiftUI
import UniformTypeIdentifiers

struct ExportImportView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var showShareJSON = false
    @State private var showSharePDF = false
    @State private var shareURL: URL?
    @State private var showImporter = false
    @State private var alertMessage: String?
    @State private var alertTitle = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                VStack(spacing: 16) {
                    PCCard(topAccent: PCColor.dataBlue) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Backup")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("JSON with all projects, settings, and templates.")
                                .font(.caption)
                                .foregroundStyle(PCColor.secondaryText)
                            PCGradientButton(title: "Export JSON…") {
                                exportJSON()
                            }
                        }
                    }
                    PCCard(topAccent: PCColor.balance) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PDF report")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Short summary of the active project for sharing or printing.")
                                .font(.caption)
                                .foregroundStyle(PCColor.secondaryText)
                            PCOutlineButton(title: "Generate PDF…", color: PCColor.balance) {
                                exportPDF()
                            }
                        }
                    }
                    PCCard(topAccent: PCColor.skew) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Restore")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Import replaces all data currently in the app.")
                                .font(.caption)
                                .foregroundStyle(PCColor.secondaryText)
                            PCOutlineButton(title: "Import from file…", color: PCColor.skew) {
                                showImporter = true
                            }
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Data exchange")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareJSON) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .sheet(isPresented: $showSharePDF) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    do {
                        let secured = url.startAccessingSecurityScopedResource()
                        defer { if secured { url.stopAccessingSecurityScopedResource() } }
                        let payload = try PersistenceService.importPayload(from: url)
                        store.replaceAllFromImport(payload)
                        presentAlert(title: "Import", message: "Import completed.")
                    } catch {
                        presentAlert(title: "Import", message: "Import failed.")
                    }
                case .failure:
                    presentAlert(title: "Import", message: "No file selected.")
                }
            }
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
    }

    private func exportJSON() {
        do {
            let url = try PersistenceService.exportURL(for: store.exportPayload())
            shareURL = url
            showShareJSON = true
        } catch {
            presentAlert(title: "Export", message: "Could not prepare JSON.")
        }
    }

    private func exportPDF() {
        guard let project = store.selectedProject else {
            presentAlert(title: "PDF", message: "No active project.")
            return
        }
        do {
            let url = try PDFReportBuilder.buildProjectReport(project: project, settings: store.settings.thresholds)
            shareURL = url
            showSharePDF = true
        } catch {
            presentAlert(title: "PDF", message: "Could not generate PDF.")
        }
    }
}


import SwiftUI

struct SnapshotHistoryView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: BalanceSnapshot?

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                if let project = store.selectedProject {
                    List {
                        ForEach(project.snapshots) { s in
                            Button {
                                editing = s
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(PCColor.secondaryText)
                                    Text(s.note.isEmpty ? "No note" : s.note)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)
                                    HStack {
                                        ForEach(PhaseLine.allCases) { p in
                                            Text("\(p.shortTitle): \(BalanceCalculator.formatA(s.ampsByPhase[p] ?? 0))")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(PCColor.secondaryText)
                                        }
                                    }
                                    Text("Imbalance: \(BalanceCalculator.formatPercent(s.imbalancePercent))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(PCColor.dataBlue)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .listRowBackground(PCColor.layer)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.deleteSnapshot(id: s.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    Text("No project")
                        .foregroundStyle(PCColor.secondaryText)
                }
            }
            .navigationTitle("Snapshots")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $editing) { snap in
                SnapshotNoteEditorSheet(snapshot: snap)
                    .environmentObject(store)
            }
        }
    }
}

private struct SnapshotNoteEditorSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    let snapshot: BalanceSnapshot
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                Form {
                    Section("Note") {
                        TextField("Text", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    .listRowBackground(PCColor.layer)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Snapshot")
            .onAppear { note = snapshot.note }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateSnapshotNote(snapshotId: snapshot.id, note: note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

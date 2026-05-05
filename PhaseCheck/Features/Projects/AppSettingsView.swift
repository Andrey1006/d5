
import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        ZStack {
            PCScreenBackground()
            Form {
                Section("Default input") {
                    Toggle("Prefer power (kW)", isOn: Binding(
                        get: { store.settings.preferPowerInsteadOfCurrent },
                        set: { v in
                            var s = store.settings
                            s.preferPowerInsteadOfCurrent = v
                            store.updateSettings(s)
                        }
                    ))
                }
                .listRowBackground(PCColor.layer)

                Section {
                    Text("New loads will open with the selected input type.")
                        .font(.caption)
                        .foregroundStyle(PCColor.secondaryText)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .tabBar)
    }
}


import SwiftUI

struct ThresholdsView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var yellow: Double = 15
    @State private var red: Double = 30
    @State private var nearLimit: Double = 90

    var body: some View {
        NavigationStack {
            ZStack {
                PCScreenBackground()
                Form {
                    Section("Presets") {
                        HStack(spacing: 8) {
                            presetButton("Strict", yellow: 10, red: 25, near: 85)
                            presetButton("Medium", yellow: 15, red: 30, near: 90)
                            presetButton("Relaxed", yellow: 25, red: 45, near: 95)
                        }
                        Text("Apply typical thresholds quickly; then fine-tune with the sliders if needed.")
                            .font(.caption2)
                            .foregroundStyle(PCColor.secondaryText)
                    }
                    .listRowBackground(PCColor.layer)

                    Section("Imbalance") {
                        VStack(alignment: .leading) {
                            Text("Yellow zone from \(Int(yellow))%")
                            Slider(value: $yellow, in: 5...40, step: 1)
                        }
                        VStack(alignment: .leading) {
                            Text("Red zone from \(Int(red))%")
                            Slider(value: $red, in: 20...60, step: 1)
                        }
                    }
                    .listRowBackground(PCColor.layer)

                    Section("Line limit") {
                        VStack(alignment: .leading) {
                            Text("Warning at \(Int(nearLimit))% of limit")
                            Slider(value: $nearLimit, in: 70...100, step: 1)
                        }
                    }
                    .listRowBackground(PCColor.layer)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Thresholds")
            .onAppear {
                yellow = store.settings.thresholds.yellowImbalancePercent
                red = store.settings.thresholds.redImbalancePercent
                nearLimit = store.settings.thresholds.criticalCurrentPercentOfLimit
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var s = store.settings
                        s.thresholds = ThresholdSettings(yellowImbalancePercent: yellow, redImbalancePercent: red, criticalCurrentPercentOfLimit: nearLimit)
                        store.updateSettings(s)
                        dismiss()
                    }
                }
            }
        }
    }

    private func presetButton(_ title: String, yellow y: Double, red r: Double, near n: Double) -> some View {
        Button(title) {
            yellow = y
            red = r
            nearLimit = n
        }
        .buttonStyle(.bordered)
        .tint(PCColor.structure)
        .foregroundStyle(.white)
    }
}

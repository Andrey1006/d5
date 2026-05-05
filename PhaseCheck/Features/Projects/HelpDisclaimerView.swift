
import SwiftUI

struct HelpDisclaimerView: View {
    var body: some View {
        ZStack {
            PCScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PCCard(topAccent: PCColor.dataBlue) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to use")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Create a project and set voltage, cos φ, and optionally a per-phase current limit. Add loads (in amps or kilowatts) and assign a phase. On the Balance tab you can simulate moving devices between phases, save scenarios, and apply them to the project. Snapshots on the dashboard and in analytics help track imbalance over time.")
                                .font(.subheadline)
                                .foregroundStyle(PCColor.secondaryText)
                        }
                    }
                    PCCard(topAccent: PCColor.critical) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ Disclaimer")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Zeuphase Check provides indicative calculations from manually entered data. Actual currents, harmonics, inrush, and grid conditions may differ. Measurements, equipment protection, and compliance with local electrical codes remain the responsibility of a qualified professional. Do not use the app as the sole basis for safety decisions.")
                                .font(.subheadline)
                                .foregroundStyle(PCColor.secondaryText)
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Help")
        .toolbar(.hidden, for: .tabBar)
    }
}

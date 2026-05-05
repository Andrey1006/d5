
import SwiftUI

struct OnboardingFlowView: View {
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @State private var page = 0

    var body: some View {
        ZStack {
            PCScreenBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        finish()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PCColor.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $page) {
                    OnboardingWelcomePage()
                        .tag(0)
                    OnboardingSafetyPage()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .fill(i == page ? PCColor.dataBlue : PCColor.structure.opacity(0.8))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 12)

                Group {
                    if page == 0 {
                        PCGradientButton(title: "Next") {
                            withAnimation(.easeInOut(duration: 0.25)) { page = 1 }
                        }
                    } else {
                        PCGradientButton(title: "Get started") {
                            finish()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }

    private func finish() {
        onboardingCompleted = true
    }
}

private struct OnboardingWelcomePage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Zeuphase Check")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Plan and review three-phase balance from the loads you enter.")
                        .font(.body)
                        .foregroundStyle(PCColor.secondaryText)
                }

                PCCard(topAccent: PCColor.dataBlue) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Projects & loads", systemImage: "folder.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                        bullet("Create projects with voltage, cos φ, and optional per-phase limits.")
                        bullet("Add devices in amps or kW, assign phases, and use templates.")
                    }
                }

                PCCard(topAccent: PCColor.balance) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Balance & analytics", systemImage: "arrow.left.arrow.right")
                            .font(.headline)
                            .foregroundStyle(.white)
                        bullet("Simulate moving single-phase loads and save scenarios to compare.")
                        bullet("Save snapshots on the dashboard to track imbalance over time.")
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "hand.draw.fill")
                        .font(.title2)
                        .foregroundStyle(PCColor.skew)
                    Text("Swipe or tap Next to continue.")
                        .font(.footnote)
                        .foregroundStyle(PCColor.secondaryText)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .foregroundStyle(PCColor.dataBlue)
                .font(.body.weight(.bold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PCColor.secondaryText)
        }
    }
}

private struct OnboardingSafetyPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before you begin")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text("A quick note on what this app is — and is not.")
                        .font(.body)
                        .foregroundStyle(PCColor.secondaryText)
                }

                PCCard(topAccent: PCColor.skew) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Indicative calculations")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Figures are based on your manual entries. Real currents, harmonics, inrush, and installation details are not modeled.")
                            .font(.subheadline)
                            .foregroundStyle(PCColor.secondaryText)
                    }
                }

                PCCard(topAccent: PCColor.critical) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your responsibility")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Measurements, protective devices, and compliance with local electrical codes remain with a qualified professional. Do not rely on Zeuphase Check alone for safety decisions.")
                            .font(.subheadline)
                            .foregroundStyle(PCColor.secondaryText)
                    }
                }

                Text("You can revisit this in Projects → Help & disclaimer.")
                    .font(.footnote)
                    .foregroundStyle(PCColor.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

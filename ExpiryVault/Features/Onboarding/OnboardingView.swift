import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.analytics) private var analytics

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .buttonStyle(.bordered)
                } else {
                    Spacer()
                }
                Spacer()
                if page < 1 {
                    Button("Continue") { withAnimation { page += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get started") { Task { await finish() } }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var welcomePage: some View {
        OnboardingPage(
            symbol: "lock.shield.fill",
            tint: .accentColor,
            title: "Never miss an expiration",
            subtitle: "Track passports, licenses, warranties, memberships, and anything else that runs out.",
            bullets: [
                ("bell.fill", "Reminders 30 / 7 / 1 day ahead (6- and 3-month with Plus)"),
                ("folder.fill", "Organize by person and category"),
                ("square.and.arrow.up", "Export your data any time"),
                ("iphone", "Everything stays on your device"),
            ],
        )
    }

    private var howItWorksPage: some View {
        OnboardingPage(
            symbol: "bell.badge.fill",
            tint: .accentColor,
            title: "Reminders that actually work",
            subtitle: "We send a local notification on the morning you ask — no login, no cloud, no surprises.",
            bullets: [
                ("plus.circle.fill", "Add your first item in under 30 seconds"),
                ("calendar", "We do the countdown math for you"),
                ("checkmark.seal.fill", "Upgrade any time for unlimited items"),
            ],
        )
    }

    private func finish() async {
        let granted = await NotificationService.shared.requestAuthorization()
        analytics.track(.onboardingCompleted, properties: [
            "success": .bool(granted),
        ])
        withAnimation { appState.onboardingCompleted = true }
    }
}

private struct OnboardingPage: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let bullets: [(String, String)]

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 32)
            Image(systemName: symbol)
                .font(.system(size: 72))
                .foregroundStyle(tint)
            Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center).padding(.horizontal)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(bullets, id: \.0) { (sym, text) in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: sym)
                            .font(.title3)
                            .foregroundStyle(tint)
                            .frame(width: 28)
                        Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            Spacer()
        }
    }
}

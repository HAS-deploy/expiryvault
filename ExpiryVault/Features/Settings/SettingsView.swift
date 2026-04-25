import SwiftUI
import SwiftData
import StoreKit
import UserNotifications
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var entitlements: EntitlementStore
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics
    @Query private var items: [TrackedItem]

    let requestPaywall: (PaywallTrigger) -> Void

    @State private var restoring = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var statusMessage: String?
    @State private var showingExporter = false
    @State private var exportDocument: ExportJSONDocument?

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection
                notificationsSection
                dataSection
                privacySection
                aboutSection
                moreFromUsSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            .task { authStatus = await NotificationService.shared.currentAuthorization() }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "expiryvault-export-\(Date.now.formatted(.iso8601.year().month().day()))",
            ) { result in
                if case let .failure(err) = result {
                    statusMessage = "Export failed: \(err.localizedDescription)"
                }
            }
        }
    }

    // MARK: Sections

    private var subscriptionSection: some View {
        Section {
            LabeledContent("Plan", value: entitlements.statusLabel)
            if entitlements.isPremium {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label("Manage subscription", systemImage: "creditcard")
                }
            } else {
                Button {
                    requestPaywall(.settings)
                } label: {
                    Label("Upgrade to Plus", systemImage: "sparkles")
                }
            }
            Button {
                Task { await runRestore() }
            } label: {
                if restoring { ProgressView() } else { Label("Restore purchases", systemImage: "arrow.clockwise") }
            }
            .disabled(restoring)
        } header: {
            Text("ExpiryVault Plus")
        } footer: {
            if !entitlements.isPremium {
                Text("Unlimited tracked items, every reminder interval, premium filters.")
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            HStack {
                Label("System permission", systemImage: "bell")
                Spacer()
                Text(permissionLabel).foregroundStyle(.secondary)
            }
            if authStatus == .denied {
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
            } else if authStatus == .notDetermined {
                Button("Allow notifications") {
                    Task {
                        _ = await NotificationService.shared.requestAuthorization()
                        authStatus = await NotificationService.shared.currentAuthorization()
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("ExpiryVault schedules local reminders — nothing is sent to a server.")
        }
    }

    private var dataSection: some View {
        Section("Your data") {
            Button {
                exportDocument = ExportJSONDocument(items: items)
                showingExporter = true
            } label: {
                Label("Export as JSON", systemImage: "square.and.arrow.up")
            }
            .disabled(items.isEmpty)
            if let statusMessage {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink {
                PrivacyView()
            } label: {
                Label("How ExpiryVault handles your data", systemImage: "lock.shield")
            }
            Link(destination: URL(string: "https://has-deploy.github.io/expiryvault/privacy.html")!) {
                Label("Privacy policy", systemImage: "link")
            }
            Link(destination: URL(string: "https://has-deploy.github.io/expiryvault/terms.html")!) {
                Label("Terms of Use", systemImage: "link")
            }
        }
    }

    private var moreFromUsSection: some View {
        Section {
            Link(destination: URL(string: "https://apps.apple.com/app/id6762404077")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HouseholdOS").font(.body).foregroundStyle(.primary)
                    Text("Bills, tasks, documents, members — your home, organized.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("More from us")
        } footer: {
            Text("Other useful apps from the same team. Tap to open in the App Store.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.marketingVersion)
            Link(destination: URL(string: "https://has-deploy.github.io/expiryvault/support.html")!) {
                Label("Support", systemImage: "questionmark.circle")
            }
            Text("ExpiryVault may collect anonymous usage metrics to improve the app. No personal document content is collected.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        Section("Developer (DEBUG only)") {
            Button(entitlements.isPremium ? "Disable premium (debug)" : "Enable premium (debug)") {
                if entitlements.isPremium {
                    entitlements.reset()
                } else {
                    entitlements.debugSetPremium(for: PricingConfig.lifetimeProductID)
                }
            }
        }
    }
    #endif

    // MARK: Actions

    private func runRestore() async {
        restoring = true
        await purchases.restore()
        restoring = false
        statusMessage = entitlements.isPremium ? "Purchases restored." : "No previous purchases found."
    }

    private var permissionLabel: String {
        switch authStatus {
        case .notDetermined: return "Not requested"
        case .denied:        return "Denied"
        case .authorized:    return "Allowed"
        case .provisional:   return "Provisional"
        case .ephemeral:     return "Ephemeral"
        @unknown default:    return "—"
        }
    }
}

private extension Bundle {
    var marketingVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

// MARK: JSON export

struct ExportJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let items: [TrackedItem]

    init(items: [TrackedItem]) { self.items = items }

    init(configuration: ReadConfiguration) throws {
        self.items = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        struct ExportEntry: Encodable {
            let id: String
            let name: String
            let category: String
            let owner: String
            let expirationDate: String
            let notes: String
            let referenceCode: String
            let remindersEnabled: Bool
            let reminderOffsetDays: [Int]
        }
        let formatter = ISO8601DateFormatter()
        let payload = items.map { i in
            ExportEntry(
                id: i.id.uuidString,
                name: i.name,
                category: i.category.rawValue,
                owner: i.ownerName,
                expirationDate: formatter.string(from: i.expirationDate),
                notes: i.notes,
                referenceCode: i.referenceCode,
                remindersEnabled: i.remindersEnabled,
                reminderOffsetDays: i.reminderOffsetDays,
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return FileWrapper(regularFileWithContents: data)
    }
}

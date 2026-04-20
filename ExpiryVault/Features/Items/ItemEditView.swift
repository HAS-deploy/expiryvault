import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.analytics) private var analytics

    /// `nil` for create, populated for edit. We don't mutate it until Save.
    let item: TrackedItem?

    @State private var name = ""
    @State private var category: ItemCategory = .travel
    @State private var ownerName = ""
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var notes = ""
    @State private var referenceCode = ""
    @State private var remindersEnabled = true
    @State private var offsets: Set<ReminderOffset> = Set(ReminderOffset.defaultsForFreeTier)
    @State private var showPremiumNudge = false

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                Picker("Category", selection: $category) {
                    ForEach(ItemCategory.allCases) { c in
                        Label(c.title, systemImage: c.symbol).tag(c)
                    }
                }
            }

            Section("Details") {
                TextField("Owner (optional)", text: $ownerName)
                    .textInputAutocapitalization(.words)
                DatePicker("Expires on", selection: $expirationDate, displayedComponents: .date)
                TextField("Reference / doc number (optional)", text: $referenceCode)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                Toggle("Remind me before it expires", isOn: $remindersEnabled)
                if remindersEnabled {
                    ForEach(ReminderOffset.allCases) { offset in
                        reminderToggle(offset)
                    }
                    if !entitlements.isPremium {
                        Text("30 / 7 / 1 day are free. Upgrade to Plus for 6- and 3-month reminders too.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Reminders")
            }
        }
        .navigationTitle(item == nil ? "New Item" : "Edit Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: load)
        .alert("Premium reminder", isPresented: $showPremiumNudge) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("6- and 3-month reminders are part of ExpiryVault Plus. Upgrade from Settings to enable them.")
        }
    }

    // MARK: Controls

    private func reminderToggle(_ offset: ReminderOffset) -> some View {
        let locked = !offset.isAllowed(premium: entitlements.isPremium)
        return Toggle(isOn: Binding(
            get: { offsets.contains(offset) && !locked },
            set: { isOn in
                if locked {
                    showPremiumNudge = true
                    return
                }
                if isOn { offsets.insert(offset) } else { offsets.remove(offset) }
            }
        )) {
            HStack {
                Text(offset.title)
                if locked {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Load / save

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func load() {
        guard let item else {
            // New item — apply premium-aware defaults.
            offsets = Set(entitlements.isPremium
                          ? ReminderOffset.defaultsForPremium
                          : ReminderOffset.defaultsForFreeTier)
            return
        }
        name = item.name
        category = item.category
        ownerName = item.ownerName
        expirationDate = item.expirationDate
        notes = item.notes
        referenceCode = item.referenceCode
        remindersEnabled = item.remindersEnabled
        offsets = Set(item.reminderOffsets)
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Enforce free-tier offset restriction defensively.
        let allowedOffsets = offsets.filter { $0.isAllowed(premium: entitlements.isPremium) }

        let target: TrackedItem
        if let existing = item {
            existing.name = trimmedName
            existing.category = category
            existing.ownerName = ownerName.trimmingCharacters(in: .whitespaces)
            existing.expirationDate = expirationDate
            existing.notes = notes.trimmingCharacters(in: .whitespaces)
            existing.referenceCode = referenceCode.trimmingCharacters(in: .whitespaces)
            existing.remindersEnabled = remindersEnabled
            existing.reminderOffsets = Array(allowedOffsets).sorted { $0.rawValue > $1.rawValue }
            existing.updatedAt = .now
            target = existing
        } else {
            let new = TrackedItem(
                name: trimmedName,
                category: category,
                ownerName: ownerName.trimmingCharacters(in: .whitespaces),
                expirationDate: expirationDate,
                notes: notes.trimmingCharacters(in: .whitespaces),
                referenceCode: referenceCode.trimmingCharacters(in: .whitespaces),
                remindersEnabled: remindersEnabled,
                reminderOffsetDays: Array(allowedOffsets).map(\.rawValue).sorted(by: >),
            )
            context.insert(new)
            target = new
        }
        try? context.save()

        // Reschedule local notifications.
        await NotificationService.shared.reschedule(for: target)

        analytics.track(item == nil ? .itemAdded : .reminderEnabled, properties: [
            "category": .category(.init(category)),
            "trigger_source": .source(.detail),
        ])
        dismiss()
    }
}

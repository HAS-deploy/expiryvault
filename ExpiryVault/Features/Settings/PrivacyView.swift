import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("What stays on your device") {
                Text("Every tracked item — its name, owner, expiration date, notes, and reference codes — is stored only in ExpiryVault's local database on this iPhone.")
                Text("Local notifications are scheduled by iOS on this device. Nothing is sent to any server.")
            }
            Section("What we don't do") {
                Label("No accounts", systemImage: "person.crop.circle.badge.xmark")
                Label("No cloud sync", systemImage: "icloud.slash")
                Label("No tracking across apps", systemImage: "nosign")
                Label("No ads", systemImage: "rectangle.stack.badge.minus")
            }
            Section("Anonymous usage metrics") {
                Text("ExpiryVault may log coarse, anonymous product events — like how many items you have in a bucket (e.g. 1-2, 3-5, 6-10) and which category you tapped. It never logs your item names, notes, reference codes, or exact expiration dates.")
            }
            Section("Your data, when you want it") {
                Text("You can export every item to JSON from Settings → Export. You can also delete an item at any time — its reminders are cleared immediately.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

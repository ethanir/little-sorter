import SwiftUI

/// The single place adults manage the app — reached ONLY by passing the parental
/// gate. Holds optional Challenge Mode, the one-time unlock + restore, and the
/// privacy/support links. Apple's Kids Category requires that purchasing and
/// links out of the app sit behind a parental gate, so they live here and are
/// never shown directly to a child.
struct GrownUpsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Binding var challengeMode: Bool

    @State private var showPaywall = false

    // TODO: Replace these with your real hosted URLs before submitting.
    // Both are REQUIRED for the App Store (Privacy Policy especially for Kids).
    private let privacyURL = URL(string: "https://littlesorter.app/privacy")!
    private let supportURL = URL(string: "https://littlesorter.app/support")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $challengeMode) {
                        Label("Challenge Mode", systemImage: "stopwatch")
                    }
                    .tint(.orange)
                    Text("Adds a gentle 30-second timer and 1–3 star rewards for older "
                         + "children. Off by default.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Play")
                }

                Section {
                    if store.isUnlocked {
                        Label("All worlds unlocked", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Unlock all worlds", systemImage: "lock.open.fill")
                        }
                        Button("Restore purchase") {
                            Task { await store.restore() }
                        }
                    }
                } header: {
                    Text("All Worlds")
                } footer: {
                    Text("Farm and Ocean are always free. Unlocking the other four worlds "
                         + "is a single one-time purchase — no subscriptions.")
                }

                Section {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: supportURL) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Little Sorter collects no data, has no ads, and never asks "
                         + "children to make purchases.")
                }
            }
            .navigationTitle("For Grown-Ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(store)
        }
    }
}

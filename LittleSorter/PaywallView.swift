import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🧩")
                .font(.system(size: 72))
            Text("Unlock All Levels")
                .font(.title.weight(.bold))
            Text("Get every world — one purchase, yours forever. No ads, no subscriptions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            if store.isProductLoaded, let price = store.priceText {
                Button {
                    Task { await store.purchase() }
                } label: {
                    Text("Unlock for \(price)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // Product not loaded yet (or load failed). Show a loader + retry —
                // never a dead button with a fake price.
                VStack(spacing: 12) {
                    ProgressView()
                    Button("Try again") { Task { await store.loadProducts() } }
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
            }

            Button("Restore Purchase") {
                Task { await store.restore() }
            }
            .font(.subheadline)

            if let err = store.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Not now") { dismiss() }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(28)
        // Single source of dismissal once the unlock lands (covers purchase & restore).
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }
}

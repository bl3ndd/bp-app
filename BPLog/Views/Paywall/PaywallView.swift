import SwiftUI
import StoreKit

/// One-time Pro unlock. Lists only what the build actually has — promising
/// anything unshipped is a guideline 2.3.1 rejection.
struct PaywallView: View {
    @Environment(PurchaseService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(AppColors.accent)
                            .padding(.top, 12)
                        Text("BP Log Pro")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppColors.textPrimary)
                        Text("One price. Yours forever.")
                            .font(.title3)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 16) {
                            benefit("doc.richtext", "Doctor-ready PDF report", "Averages, a chart and every reading, ready to print or email before your appointment.")
                            benefit("chart.bar.xaxis", "Full statistics", "Morning vs. evening, trends, time in your target range, and more.")
                            benefit("chart.xyaxis.line", "All-time charts", "See 90 days, a year, or your whole history.")
                        }
                    }

                    Label("No subscription. No ads.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(AppColors.normal)

                    VStack(spacing: 10) {
                        buyButton
                        Text("One-time purchase. Logging, history, Apple Health and backups always stay free.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Restore Purchases") {
                        Task { await purchases.restore() }
                    }
                    .font(.body.weight(.medium))
                    .disabled(purchases.isWorking)
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .alert("Purchase didn't go through", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again, or tap Restore Purchases if you've bought Pro before.")
            }
            .onChange(of: purchases.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var buyButton: some View {
        Button {
            Task {
                guard purchases.product != nil else { await purchases.load(); return }
                do {
                    _ = try await purchases.purchase()
                } catch {
                    failed = true
                }
            }
        } label: {
            if purchases.isWorking {
                ProgressView().tint(.white)
            } else if let product = purchases.product {
                Text("Unlock Pro — \(product.displayPrice)")
            } else if purchases.loaded {
                // The store answered with nothing (offline, or the product isn't live yet).
                Text("Price unavailable. Tap to retry")
            } else {
                Text("Loading…")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(purchases.isWorking || !(purchases.loaded || purchases.product != nil))
    }

    private func benefit(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColors.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(AppColors.textPrimary)
                Text(text).font(.subheadline).foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Small "this is paid" capsule next to doors into Pro. Callers hide it once Pro is owned.
struct ProMark: View {
    var body: some View {
        Label("Pro", systemImage: "lock.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppColors.accent.opacity(0.14)))
    }
}

import SwiftUI
import VisionKit

/// Point the camera at the monitor's screen; once the same numbers are read a
/// few times in a row they're offered, and the person taps to use them. Text is
/// recognized on the device and nothing is photographed or kept.
struct ScanMonitorView: View {
    var onUse: (MonitorReader.Result) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var found: MonitorReader.Result?

    /// Needs a camera and a recent enough chip; the button is hidden where it isn't.
    static var isSupported: Bool { DataScannerViewController.isSupported }

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isAvailable {
                    MonitorScanner(found: $found)
                        .ignoresSafeArea()
                } else {
                    ContentUnavailableView {
                        Label("Camera is off", systemImage: "camera.fill")
                    } description: {
                        Text("Allow camera access for Simply BP in the Settings app to scan your monitor, or type the numbers in.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
            }
            .navigationTitle("Scan Your Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { panel }
            .sensoryFeedback(.success, trigger: found)
        }
    }

    private var panel: some View {
        VStack(spacing: 12) {
            if let found {
                Text(found.pulse.map { "\(found.systolic)/\(found.diastolic) · pulse \($0)" } ?? "\(found.systolic)/\(found.diastolic)")
                    .font(AppFont.number(40))
                    .foregroundStyle(AppColors.textPrimary)
                Button("Use These Numbers") {
                    onUse(found)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("Check them against your monitor before saving.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("Hold your phone over the monitor's screen so all the numbers fit in view.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .animation(.default, value: found)
    }
}

/// VisionKit's live text scanner, reporting a reading once it has been stable for a few frames.
private struct MonitorScanner: UIViewControllerRepresentable {
    @Binding var found: MonitorReader.Result?

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate,
                                                recognizesMultipleItems: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(found: $found) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        /// The same result this many updates in a row: one blurry frame can't fill in wrong numbers.
        private static let stableUpdates = 3
        private let found: Binding<MonitorReader.Result?>
        private var last: MonitorReader.Result?
        private var streak = 0

        init(found: Binding<MonitorReader.Result?>) {
            self.found = found
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            consider(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) {
            consider(allItems)
        }

        private func consider(_ items: [RecognizedItem]) {
            let texts: [MonitorReader.Item] = items.compactMap { item in
                guard case .text(let text) = item else { return nil }
                let b = item.bounds
                let xs = [b.topLeft.x, b.topRight.x, b.bottomLeft.x, b.bottomRight.x]
                let ys = [b.topLeft.y, b.topRight.y, b.bottomLeft.y, b.bottomRight.y]
                let rect = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
                return MonitorReader.Item(text: text.transcript, rect: rect)
            }
            guard let result = MonitorReader.read(texts) else { return }
            streak = result == last ? streak + 1 : 1
            last = result
            if streak >= Self.stableUpdates, found.wrappedValue != result {
                found.wrappedValue = result
            }
        }
    }
}

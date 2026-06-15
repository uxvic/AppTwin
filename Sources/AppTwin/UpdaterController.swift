import SwiftUI
import Sparkle

/// Thin wrapper around Sparkle's standard updater so SwiftUI can drive
/// "Check for Updates…" and reflect whether a check is currently possible.
@MainActor
final class UpdaterController: ObservableObject {
    private let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    var automaticChecksEnabled: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    init() {
        // In headless --cli mode we never want the updater scheduling checks.
        let isCLI = CommandLine.arguments.contains("--cli")
        controller = SPUStandardUpdaterController(
            startingUpdater: !isCLI,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

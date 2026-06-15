import SwiftUI

@main
struct AppTwinApp: App {
    @StateObject private var store = CloneStore()
    @StateObject private var updater = UpdaterController()

    init() {
        // Headless mode for scripting/tests; exits the process when --cli is present.
        CLIRunner.runIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            CloneListView()
                .environmentObject(store)
                .environmentObject(updater)
                .frame(minWidth: 720, minHeight: 460)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }

        MenuBarExtra("AppTwin", systemImage: "square.on.square") {
            if store.clones.isEmpty {
                Text("No clones yet")
            } else {
                ForEach(store.clones) { clone in
                    Button("Launch \(clone.name)") {
                        try? CloneEngine.launch(clone)
                    }
                }
            }
            Divider()
            Button("Open AppTwin") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}

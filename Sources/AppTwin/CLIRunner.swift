import Foundation

/// Headless mode: `AppTwin --cli <command>` performs clone operations without
/// showing the GUI. Used for scripting and automated verification.
///
///   AppTwin --cli list
///   AppTwin --cli inspect <app-path>
///   AppTwin --cli create <app-path> <clone-name> [electronLauncher|electronFullClone|nativeRewrite]
///   AppTwin --cli launch <clone-name>
///   AppTwin --cli delete <clone-name> [--keep-data]
///   AppTwin --cli resync <clone-name>
enum CLIRunner {
    @MainActor
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let cliIndex = args.firstIndex(of: "--cli") else { return }
        let rest = Array(args[(cliIndex + 1)...])
        guard let command = rest.first else {
            fail("missing command after --cli")
        }
        let store = CloneStore()

        switch command {
        case "list":
            if store.clones.isEmpty { print("no clones") }
            for c in store.clones {
                print("\(c.name)\t\(c.strategy.rawValue)\t\(c.launcherAppPath)")
            }
            exit(0)

        case "inspect":
            guard rest.count >= 2 else { fail("usage: --cli inspect <app-path>") }
            do {
                let info = try AppInspector.inspect(appAt: rest[1])
                print("name: \(info.name)")
                print("bundleID: \(info.bundleID)")
                print("version: \(info.version)")
                print("electron: \(info.isElectron)  chromium: \(info.isChromiumBrowser)")
                print("asarIntegrity: \(info.hasAsarIntegrity)  fullCloneSupported: \(info.fullCloneSupported)")
                print("sandboxed: \(info.isSandboxed)  masReceipt: \(info.isMAS)")
                print("recommendedStrategy: \(info.recommendedStrategy.rawValue)")
                exit(0)
            } catch { fail(error.localizedDescription) }

        case "create":
            guard rest.count >= 3 else {
                fail("usage: --cli create <app-path> <clone-name> [strategy]")
            }
            do {
                let info = try AppInspector.inspect(appAt: rest[1])
                let strategy: CloneStrategy
                if rest.count >= 4 {
                    guard let s = CloneStrategy(rawValue: rest[3]) else {
                        fail("unknown strategy \(rest[3])")
                    }
                    strategy = s
                } else {
                    strategy = info.recommendedStrategy
                }
                let clone = try CloneEngine.create(from: info, name: rest[2], strategy: strategy)
                store.add(clone)
                print("created: \(clone.launcherAppPath)")
                print("strategy: \(clone.strategy.rawValue)")
                if !clone.dataDir.isEmpty { print("dataDir: \(clone.dataDir)") }
                exit(0)
            } catch { fail(error.localizedDescription) }

        case "launch":
            guard rest.count >= 2 else { fail("usage: --cli launch <clone-name>") }
            guard let clone = store.clones.first(where: { $0.name == rest[1] }) else {
                fail("no clone named \(rest[1])")
            }
            do { try CloneEngine.launch(clone); print("launched \(clone.name)"); exit(0) }
            catch { fail(error.localizedDescription) }

        case "delete":
            guard rest.count >= 2 else { fail("usage: --cli delete <clone-name> [--keep-data]") }
            guard let clone = store.clones.first(where: { $0.name == rest[1] }) else {
                fail("no clone named \(rest[1])")
            }
            do {
                try CloneEngine.delete(clone, removeData: !rest.contains("--keep-data"))
                store.remove(clone)
                print("deleted \(clone.name)")
                exit(0)
            } catch { fail(error.localizedDescription) }

        case "resync":
            guard rest.count >= 2 else { fail("usage: --cli resync <clone-name>") }
            guard let clone = store.clones.first(where: { $0.name == rest[1] }) else {
                fail("no clone named \(rest[1])")
            }
            do { try CloneEngine.resync(clone); print("resynced \(clone.name)"); exit(0) }
            catch { fail(error.localizedDescription) }

        default:
            fail("unknown command \(command)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data(("apptwin: " + message + "\n").utf8))
        exit(1)
    }
}

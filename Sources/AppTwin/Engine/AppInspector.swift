import Foundation

struct AppInfo: Identifiable, Hashable, Sendable {
    var id: String { appPath }
    let appPath: String
    let bundleID: String
    let name: String
    let version: String
    let executableName: String
    let isElectron: Bool
    let isChromiumBrowser: Bool
    let isMAS: Bool
    let prohibitsMultipleInstances: Bool
    /// Electron asar integrity is enforced (Info.plist carries ElectronAsarIntegrity).
    /// When true, modifying + re-signing the bundle makes the app trap on launch,
    /// so a full clone is not viable — only a launcher.
    let hasAsarIntegrity: Bool
    /// Only meaningful when entitlementsChecked is true (full inspect).
    let isSandboxed: Bool
    let entitlementsChecked: Bool

    var recommendedStrategy: CloneStrategy {
        if isMAS || (entitlementsChecked && isSandboxed) { return .unsupported }
        if isElectron || isChromiumBrowser { return .electronLauncher }
        return .nativeRewrite
    }

    /// Whether a full clone (own Dock identity) can be built without the app
    /// trapping on launch. Hardened Electron apps with asar integrity cannot.
    var fullCloneSupported: Bool {
        (isElectron || isChromiumBrowser) && !hasAsarIntegrity
    }

    /// Short badge for the app library list (based on the quick scan).
    var clonabilityBadge: String {
        switch recommendedStrategy {
        case .electronLauncher, .electronFullClone: return "Cloneable"
        case .nativeRewrite: return "Best effort"
        case .unsupported: return "Not cloneable"
        }
    }
}

enum AppInspectorError: LocalizedError {
    case notAnApp(String)
    case unreadablePlist(String)

    var errorDescription: String? {
        switch self {
        case .notAnApp(let p): return "\(p) is not an application bundle."
        case .unreadablePlist(let p): return "Could not read Info.plist for \(p)."
        }
    }
}

enum AppInspector {
    private static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi",
        "org.chromium.Chromium", "company.thebrowser.Browser", "com.operasoftware.Opera",
    ]

    /// Fast, file-system-only inspection. Suitable for scanning every installed app.
    static func quickInspect(appAt path: String) throws -> AppInfo {
        let fm = FileManager.default
        let contents = (path as NSString).appendingPathComponent("Contents")
        let plistPath = (contents as NSString).appendingPathComponent("Info.plist")

        guard path.hasSuffix(".app"), fm.fileExists(atPath: plistPath) else {
            throw AppInspectorError.notAnApp(path)
        }
        guard let data = fm.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else {
            throw AppInspectorError.unreadablePlist(path)
        }

        let bundleID = dict["CFBundleIdentifier"] as? String ?? ""
        let name = dict["CFBundleDisplayName"] as? String
            ?? dict["CFBundleName"] as? String
            ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let version = dict["CFBundleShortVersionString"] as? String ?? ""
        let executable = dict["CFBundleExecutable"] as? String ?? ""

        let isElectron =
            fm.fileExists(atPath: (contents as NSString).appendingPathComponent("Frameworks/Electron Framework.framework"))
            || fm.fileExists(atPath: (contents as NSString).appendingPathComponent("Resources/app.asar"))
        let isChromium = chromiumBundleIDs.contains(bundleID)
        let isMAS = fm.fileExists(atPath: (contents as NSString).appendingPathComponent("_MASReceipt/receipt"))
        let prohibitsMulti = (dict["LSMultipleInstancesProhibited"] as? Bool) ?? false
        let hasAsarIntegrity = dict["ElectronAsarIntegrity"] != nil

        return AppInfo(
            appPath: path,
            bundleID: bundleID,
            name: name,
            version: version,
            executableName: executable,
            isElectron: isElectron,
            isChromiumBrowser: isChromium,
            isMAS: isMAS,
            prohibitsMultipleInstances: prohibitsMulti,
            hasAsarIntegrity: hasAsarIntegrity,
            isSandboxed: false,
            entitlementsChecked: false
        )
    }

    /// Full inspection: quick scan plus a codesign entitlements check for the app sandbox.
    static func inspect(appAt path: String) throws -> AppInfo {
        let quick = try quickInspect(appAt: path)
        var sandboxed = false
        if let result = try? ShellRunner.run(
            "/usr/bin/codesign", ["-d", "--entitlements", "-", "--xml", path], check: false
        ) {
            let combined = result.stdout + result.stderr
            if combined.contains("com.apple.security.app-sandbox") {
                // Parse to confirm the value is true; fall back to substring presence.
                if let data = result.stdout.data(using: .utf8),
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                   let dict = plist as? [String: Any] {
                    sandboxed = (dict["com.apple.security.app-sandbox"] as? Bool) ?? true
                } else {
                    sandboxed = true
                }
            }
        }
        return AppInfo(
            appPath: quick.appPath,
            bundleID: quick.bundleID,
            name: quick.name,
            version: quick.version,
            executableName: quick.executableName,
            isElectron: quick.isElectron,
            isChromiumBrowser: quick.isChromiumBrowser,
            isMAS: quick.isMAS,
            prohibitsMultipleInstances: quick.prohibitsMultipleInstances,
            hasAsarIntegrity: quick.hasAsarIntegrity,
            isSandboxed: sandboxed,
            entitlementsChecked: true
        )
    }

    /// Scans the standard application folders (top level + /Applications/Utilities).
    static func installedApps() -> [AppInfo] {
        let fm = FileManager.default
        var dirs = [
            "/Applications",
            "/Applications/Utilities",
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ]
        // Skip our own generated clones.
        let launchers = AppTwinPaths.launchersDir.path
        dirs.removeAll { $0 == launchers }

        var apps: [AppInfo] = []
        for dir in dirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let path = (dir as NSString).appendingPathComponent(entry)
                if path.hasPrefix(launchers) { continue }
                if let info = try? quickInspect(appAt: path) {
                    apps.append(info)
                }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

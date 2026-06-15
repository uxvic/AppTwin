import Foundation

/// Builds Strategy A1 clones: a small standalone launcher .app that starts the
/// ORIGINAL app with `--user-data-dir=<profile>`, giving it an isolated login
/// without touching the original bundle.
enum ElectronLauncherBuilder {
    struct LaunchConfig: Codable {
        let mode: String
        let target: String
        let args: [String]
    }

    static func buildLauncher(for info: AppInfo, cloneName: String, cloneID: UUID,
                              profileDir: URL) throws -> URL {
        let fm = FileManager.default
        let safeName = AppTwinPaths.bundleName(for: cloneName)
        let launcherURL = AppTwinPaths.launchersDir.appendingPathComponent("\(safeName).app")

        guard !fm.fileExists(atPath: launcherURL.path) else {
            throw CloneEngineError.nameInUse(safeName)
        }

        let contents = launcherURL.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")
        try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)
        try fm.createDirectory(at: profileDir, withIntermediateDirectories: true)

        // 1. The stub executable.
        let stub = try stubBinaryURL()
        let execURL = macOS.appendingPathComponent("AppTwinLauncher")
        try fm.copyItem(at: stub, to: execURL)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execURL.path)

        // 2. launch.json — open the original app with an isolated profile.
        let config = LaunchConfig(
            mode: "open",
            target: info.appPath,
            args: ["--user-data-dir=\(profileDir.path)"]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: resources.appendingPathComponent("launch.json"))

        // 3. Icon: borrow the original app's icon, badged so the clone is
        //    distinguishable in Finder / Launchpad / the Dock.
        let iconURL = resources.appendingPathComponent("AppIcon.icns")
        let hasIcon = copyIcon(from: info.appPath, to: iconURL)
        if hasIcon { IconBadger.badge(iconURL: iconURL) }

        // 4. Info.plist. LSUIElement keeps the short-lived stub out of the Dock.
        var plist: [String: Any] = [
            "CFBundleIdentifier": "com.apptwin.clone.\(cloneID.uuidString)",
            "CFBundleName": cloneName,
            "CFBundleDisplayName": cloneName,
            "CFBundleExecutable": "AppTwinLauncher",
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "11.0",
            "LSUIElement": true,
        ]
        if hasIcon { plist["CFBundleIconFile"] = "AppIcon" }
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist,
                                                           format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))

        // 5. Sign and register.
        try CodeSigner.adhocSign(launcherURL.path)
        CodeSigner.removeQuarantine(launcherURL.path)
        CodeSigner.registerWithLaunchServices(launcherURL.path)

        return launcherURL
    }

    /// Locates the AppTwinStub binary: inside the app bundle's Resources when
    /// running as AppTwin.app, or next to the executable in a SPM dev build.
    static func stubBinaryURL() throws -> URL {
        if let bundled = Bundle.main.url(forResource: "AppTwinStub", withExtension: nil),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        let exeDir = (Bundle.main.executableURL
                      ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        let sibling = exeDir.appendingPathComponent("AppTwinStub")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }
        throw CloneEngineError.stubMissing
    }

    /// Copies the source app's .icns into the clone. Returns false when the app
    /// has no classic .icns (e.g. asset-catalog-only icons).
    @discardableResult
    static func copyIcon(from appPath: String, to destination: URL) -> Bool {
        let fm = FileManager.default
        let resources = (appPath as NSString).appendingPathComponent("Contents/Resources")
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

        var iconFile: String?
        if let data = fm.contents(atPath: plistPath),
           let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] {
            iconFile = dict["CFBundleIconFile"] as? String
        }
        if var icon = iconFile {
            if !icon.hasSuffix(".icns") { icon += ".icns" }
            let src = (resources as NSString).appendingPathComponent(icon)
            if fm.fileExists(atPath: src) {
                try? fm.removeItem(at: destination)
                if (try? fm.copyItem(atPath: src, toPath: destination.path)) != nil { return true }
            }
        }
        // Fallback: first .icns in Resources.
        if let entries = try? fm.contentsOfDirectory(atPath: resources),
           let first = entries.first(where: { $0.hasSuffix(".icns") }) {
            let src = (resources as NSString).appendingPathComponent(first)
            try? fm.removeItem(at: destination)
            if (try? fm.copyItem(atPath: src, toPath: destination.path)) != nil { return true }
        }
        return false
    }
}

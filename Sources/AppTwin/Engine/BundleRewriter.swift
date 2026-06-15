import Foundation

/// Strategy B: best-effort cloning of native (non-Electron, non-sandboxed) apps.
/// Copies the bundle and rewrites its identity. Preferences (keyed by bundle id)
/// separate cleanly; Application Support separates only when the app derives its
/// storage path from the bundle id.
enum BundleRewriter {
    static func buildNativeClone(for info: AppInfo, cloneName: String, cloneID: UUID) throws -> URL {
        let fm = FileManager.default
        let safeName = AppTwinPaths.bundleName(for: cloneName)
        let cloneURL = AppTwinPaths.launchersDir.appendingPathComponent("\(safeName).app")

        guard !fm.fileExists(atPath: cloneURL.path) else {
            throw CloneEngineError.nameInUse(safeName)
        }
        try fm.createDirectory(at: AppTwinPaths.launchersDir, withIntermediateDirectories: true)

        try ShellRunner.run("/usr/bin/ditto", [info.appPath, cloneURL.path])
        try rewriteIdentity(ofAppAt: cloneURL.path,
                            bundleID: "com.apptwin.clone.\(cloneID.uuidString)",
                            name: cloneName)
        try CodeSigner.adhocSign(cloneURL.path)
        CodeSigner.removeQuarantine(cloneURL.path)
        CodeSigner.registerWithLaunchServices(cloneURL.path)
        return cloneURL
    }

    /// Rewrites CFBundleIdentifier / CFBundleName / CFBundleDisplayName in place.
    static func rewriteIdentity(ofAppAt appPath: String, bundleID: String, name: String) throws {
        let plistURL = URL(fileURLWithPath: appPath)
            .appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard var dict = try PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any] else {
            throw AppInspectorError.unreadablePlist(appPath)
        }
        dict["CFBundleIdentifier"] = bundleID
        dict["CFBundleName"] = name
        dict["CFBundleDisplayName"] = name
        let out = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try out.write(to: plistURL)
    }
}

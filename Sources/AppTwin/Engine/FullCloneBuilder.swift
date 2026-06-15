import Foundation

/// Builds Strategy A2 clones: a full copy of the source app with its own
/// identity. The real main executable is renamed to "<name>.real" and replaced
/// by the AppTwin stub, which execs it with --user-data-dir so the clone gets
/// an isolated profile while keeping the clone bundle's Dock identity.
enum FullCloneBuilder {
    static func buildFullClone(for info: AppInfo, cloneName: String, cloneID: UUID,
                               profileDir: URL) throws -> URL {
        let fm = FileManager.default
        let safeName = AppTwinPaths.bundleName(for: cloneName)
        let cloneURL = AppTwinPaths.launchersDir.appendingPathComponent("\(safeName).app")

        guard !fm.fileExists(atPath: cloneURL.path) else {
            throw CloneEngineError.nameInUse(safeName)
        }
        guard !info.executableName.isEmpty else {
            throw CloneEngineError.invalidSource("missing CFBundleExecutable")
        }

        try fm.createDirectory(at: AppTwinPaths.launchersDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: profileDir, withIntermediateDirectories: true)

        // 1. Faithful copy of the whole bundle.
        try ShellRunner.run("/usr/bin/ditto", [info.appPath, cloneURL.path])

        let contents = cloneURL.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")

        // 2. Wrap the main executable with the stub (exec mode).
        let realExec = macOS.appendingPathComponent(info.executableName)
        let renamedExec = macOS.appendingPathComponent("\(info.executableName).real")
        try fm.moveItem(at: realExec, to: renamedExec)
        let stub = try ElectronLauncherBuilder.stubBinaryURL()
        try fm.copyItem(at: stub, to: realExec)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: realExec.path)

        let config = ElectronLauncherBuilder.LaunchConfig(
            mode: "exec",
            target: "MacOS/\(info.executableName).real",
            args: ["--user-data-dir=\(profileDir.path)"]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: resources.appendingPathComponent("launch.json"))

        // 3. New identity in Info.plist.
        try BundleRewriter.rewriteIdentity(
            ofAppAt: cloneURL.path,
            bundleID: "com.apptwin.clone.\(cloneID.uuidString)",
            name: cloneName
        )

        // 4. Re-sign (ad-hoc, no hardened runtime — JIT keeps working without
        //    the original's entitlements) and register.
        try CodeSigner.adhocSign(cloneURL.path)
        CodeSigner.removeQuarantine(cloneURL.path)
        CodeSigner.registerWithLaunchServices(cloneURL.path)

        return cloneURL
    }
}

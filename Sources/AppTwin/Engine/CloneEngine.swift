import Foundation

enum CloneEngineError: LocalizedError {
    case unsupported(String)
    case nameInUse(String)
    case stubMissing
    case invalidSource(String)
    case wrongStrategy

    var errorDescription: String? {
        switch self {
        case .unsupported(let why):
            return why
        case .nameInUse(let name):
            return "A clone named “\(name)” already exists. Pick a different name."
        case .stubMissing:
            return "The AppTwin launcher stub binary could not be found. Rebuild AppTwin with build.sh."
        case .invalidSource(let why):
            return "The selected app cannot be cloned: \(why)."
        case .wrongStrategy:
            return "The chosen clone strategy does not match this app type."
        }
    }
}

enum CloneEngine {
    static func create(from info: AppInfo, name: String, strategy: CloneStrategy) throws -> Clone {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CloneEngineError.invalidSource("empty clone name") }
        try FileManager.default.createDirectory(at: AppTwinPaths.launchersDir,
                                                withIntermediateDirectories: true)
        let id = UUID()
        let cloneBundleID = "com.apptwin.clone.\(id.uuidString)"

        switch strategy {
        case .electronLauncher:
            guard info.isElectron || info.isChromiumBrowser else { throw CloneEngineError.wrongStrategy }
            let profile = AppTwinPaths.profileDir(for: id)
            let launcher = try ElectronLauncherBuilder.buildLauncher(
                for: info, cloneName: trimmed, cloneID: id, profileDir: profile)
            return Clone(id: id, name: trimmed, sourceAppPath: info.appPath,
                         sourceBundleID: info.bundleID, sourceName: info.name,
                         cloneBundleID: cloneBundleID, strategy: strategy,
                         dataDir: profile.path, launcherAppPath: launcher.path,
                         createdAt: Date())

        case .electronFullClone:
            guard info.isElectron || info.isChromiumBrowser else { throw CloneEngineError.wrongStrategy }
            guard info.fullCloneSupported else {
                throw CloneEngineError.unsupported(
                    "\(info.name) enforces Electron asar integrity, so a re-signed full clone traps on launch. Use a launcher clone instead — it gives \(info.name) its own data and account without modifying the app.")
            }
            let profile = AppTwinPaths.profileDir(for: id)
            let cloneApp = try FullCloneBuilder.buildFullClone(
                for: info, cloneName: trimmed, cloneID: id, profileDir: profile)
            return Clone(id: id, name: trimmed, sourceAppPath: info.appPath,
                         sourceBundleID: info.bundleID, sourceName: info.name,
                         cloneBundleID: cloneBundleID, strategy: strategy,
                         dataDir: profile.path, launcherAppPath: cloneApp.path,
                         createdAt: Date())

        case .nativeRewrite:
            let cloneApp = try BundleRewriter.buildNativeClone(
                for: info, cloneName: trimmed, cloneID: id)
            return Clone(id: id, name: trimmed, sourceAppPath: info.appPath,
                         sourceBundleID: info.bundleID, sourceName: info.name,
                         cloneBundleID: cloneBundleID, strategy: strategy,
                         dataDir: "", launcherAppPath: cloneApp.path,
                         createdAt: Date())

        case .unsupported:
            throw CloneEngineError.unsupported(CloneStrategy.unsupported.caveat)
        }
    }

    static func launch(_ clone: Clone) throws {
        try ShellRunner.run("/usr/bin/open", [clone.launcherAppPath])
    }

    static func delete(_ clone: Clone, removeData: Bool) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: clone.launcherAppPath) {
            try fm.removeItem(atPath: clone.launcherAppPath)
        }
        if removeData {
            let dataRoot = AppTwinPaths.cloneDataRoot(for: clone.id)
            if fm.fileExists(atPath: dataRoot.path) {
                try fm.removeItem(at: dataRoot)
            }
        }
    }

    /// Rebuilds a full clone / native clone from the (possibly updated) source
    /// app, preserving the clone's profile data. No-op for launchers, which
    /// always start the live original.
    static func resync(_ clone: Clone) throws {
        guard clone.strategy == .electronFullClone || clone.strategy == .nativeRewrite else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: clone.sourceAppPath) else {
            throw CloneEngineError.invalidSource("the original app at \(clone.sourceAppPath) no longer exists")
        }
        let info = try AppInspector.inspect(appAt: clone.sourceAppPath)

        if fm.fileExists(atPath: clone.launcherAppPath) {
            try fm.removeItem(atPath: clone.launcherAppPath)
        }
        switch clone.strategy {
        case .electronFullClone:
            _ = try FullCloneBuilder.buildFullClone(
                for: info, cloneName: clone.name, cloneID: clone.id,
                profileDir: AppTwinPaths.profileDir(for: clone.id))
        case .nativeRewrite:
            _ = try BundleRewriter.buildNativeClone(
                for: info, cloneName: clone.name, cloneID: clone.id)
        default:
            break
        }
    }
}

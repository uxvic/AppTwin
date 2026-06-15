import Foundation

enum AppTwinPaths {
    static var appSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppTwin")
    }

    static var storeFile: URL {
        appSupport.appendingPathComponent("clones.json")
    }

    static var clonesDataDir: URL {
        appSupport.appendingPathComponent("clones")
    }

    /// Per-clone isolated profile / user-data directory.
    static func profileDir(for id: UUID) -> URL {
        clonesDataDir.appendingPathComponent(id.uuidString).appendingPathComponent("profile")
    }

    static func cloneDataRoot(for id: UUID) -> URL {
        clonesDataDir.appendingPathComponent(id.uuidString)
    }

    /// Where generated launcher / clone .apps live (visible to Spotlight and Launchpad).
    static var launchersDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .appendingPathComponent("AppTwin")
    }

    /// Sanitizes a clone name for use as a file name.
    static func bundleName(for cloneName: String) -> String {
        cloneName.replacingOccurrences(of: "/", with: "-")
                 .replacingOccurrences(of: ":", with: "-")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

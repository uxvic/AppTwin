import Foundation

enum CloneStrategy: String, Codable, CaseIterable, Sendable {
    case electronLauncher   // A1: launcher .app pointing the original at its own profile dir
    case electronFullClone  // A2: full copy with rewritten identity + wrapped executable
    case nativeRewrite      // B: bundle id/name rewrite, best-effort data isolation
    case unsupported        // C: sandboxed / Mac App Store

    var label: String {
        switch self {
        case .electronLauncher:  return "Launcher (recommended)"
        case .electronFullClone: return "Full clone"
        case .nativeRewrite:     return "Native rewrite (best effort)"
        case .unsupported:       return "Unsupported"
        }
    }

    var caveat: String {
        switch self {
        case .electronLauncher:
            return "The original app is never modified, so the clone survives app updates. The running clone shows the original app's Dock icon — only the Launchpad/Spotlight entry carries the clone name."
        case .electronFullClone:
            return "A full copy with its own name, Dock identity and icon. Uses as much disk as the original, is re-signed locally (ad-hoc), and needs a Re-sync after the original app updates."
        case .nativeRewrite:
            return "Works only for apps that key their data off the bundle identifier. Apps that hardcode their storage path will still share data (and logins) with the original."
        case .unsupported:
            return "Sandboxed and Mac App Store apps bind their data container to a signed bundle identifier and cannot be cloned. Use a separate macOS user account with Fast User Switching, or the app's own multi-account feature."
        }
    }
}

struct Clone: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var sourceAppPath: String
    var sourceBundleID: String
    var sourceName: String
    var cloneBundleID: String
    var strategy: CloneStrategy
    var dataDir: String          // empty when AppTwin does not manage the data dir (nativeRewrite)
    var launcherAppPath: String  // the generated .app (launcher or full clone)
    var createdAt: Date
}

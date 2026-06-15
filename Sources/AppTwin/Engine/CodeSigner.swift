import Foundation

enum CodeSigner {
    /// Ad-hoc signs a bundle in place. Local-machine only; fine for generated clones.
    static func adhocSign(_ bundlePath: String) throws {
        try ShellRunner.run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundlePath])
    }

    static func removeQuarantine(_ path: String) {
        _ = try? ShellRunner.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", path], check: false)
    }

    /// Registers a freshly generated .app with LaunchServices so Spotlight/Launchpad see it.
    static func registerWithLaunchServices(_ appPath: String) {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        _ = try? ShellRunner.run(lsregister, ["-f", appPath], check: false)
    }
}

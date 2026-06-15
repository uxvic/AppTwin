import Foundation

// AppTwin launcher stub. Installed as the main executable of a generated clone
// or launcher bundle. Reads Contents/Resources/launch.json and either:
//   mode "open" — open -n -a <target> --args <args...>  (lightweight launcher;
//                 the original app bundle is never modified)
//   mode "exec" — execv(<target>, args)                 (full clone; replaces
//                 this process so the app keeps the clone bundle's identity)

struct LaunchConfig: Codable {
    let mode: String
    let target: String
    let args: [String]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("AppTwin stub: " + message + "\n").utf8))
    exit(1)
}

let exeURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let contentsURL = exeURL.deletingLastPathComponent().deletingLastPathComponent()
let configURL = contentsURL.appendingPathComponent("Resources/launch.json")

guard let data = try? Data(contentsOf: configURL),
      let config = try? JSONDecoder().decode(LaunchConfig.self, from: data) else {
    fail("missing or invalid launch.json at \(configURL.path)")
}

// Resolve target relative to Contents/ when not absolute.
let targetPath = config.target.hasPrefix("/")
    ? config.target
    : contentsURL.appendingPathComponent(config.target).path

// Pass through any extra arguments macOS handed us (e.g. opened files),
// skipping the legacy -psn_ process serial number.
let passthrough = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }

switch config.mode {
case "open":
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = ["-n", "-a", targetPath, "--args"] + config.args + passthrough
    do { try p.run() } catch { fail("could not run open: \(error)") }
    p.waitUntilExit()
    exit(p.terminationStatus)

case "exec":
    let argv = [targetPath] + config.args + passthrough
    var cArgs: [UnsafeMutablePointer<CChar>?] = argv.map { strdup($0) }
    cArgs.append(nil)
    execv(targetPath, cArgs)
    fail("execv failed for \(targetPath): \(String(cString: strerror(errno)))")

default:
    fail("unknown mode \(config.mode)")
}

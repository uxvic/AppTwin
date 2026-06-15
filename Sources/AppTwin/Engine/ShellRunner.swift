import Foundation

struct ShellResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
    var ok: Bool { status == 0 }
}

enum ShellError: LocalizedError {
    case failed(tool: String, result: ShellResult)

    var errorDescription: String? {
        switch self {
        case .failed(let tool, let result):
            let detail = result.stderr.isEmpty ? result.stdout : result.stderr
            return "\(tool) failed (exit \(result.status)): \(detail.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

enum ShellRunner {
    /// Runs a tool synchronously and captures output. Call off the main thread for slow tools.
    @discardableResult
    static func run(_ tool: String, _ args: [String], check: Bool = true) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        // Drain pipes before waiting to avoid deadlock on large output.
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let result = ShellResult(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
        if check && !result.ok {
            throw ShellError.failed(tool: (tool as NSString).lastPathComponent, result: result)
        }
        return result
    }
}

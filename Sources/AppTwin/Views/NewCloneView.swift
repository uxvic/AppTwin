import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NewCloneView: View {
    @EnvironmentObject private var store: CloneStore
    @Environment(\.dismiss) private var dismiss

    @State private var apps: [AppInfo] = []
    @State private var isScanning = true
    @State private var search = ""
    @State private var selectedApp: AppInfo?      // full-inspected
    @State private var isInspecting = false
    @State private var cloneName = ""
    @State private var strategy: CloneStrategy = .electronLauncher
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if let app = selectedApp {
                configure(app)
            } else {
                appPicker
            }
        }
        .frame(width: 560, height: 520)
        .alert("Couldn’t create clone", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Step 1: pick any installed app

    private var appPicker: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose an app to clone")
                    .font(.headline)
                Spacer()
                Button("Browse…", action: browse)
                Button("Cancel") { dismiss() }
            }
            .padding()

            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if isScanning {
                Spacer()
                ProgressView("Scanning installed apps…")
                Spacer()
            } else {
                List(filteredApps) { app in
                    Button {
                        select(app)
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.appPath))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                Text(app.bundleID)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            badge(for: app)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .task {
            let scanned = await Task.detached { AppInspector.installedApps() }.value
            apps = scanned
            isScanning = false
        }
        .overlay {
            if isInspecting {
                ProgressView("Checking app…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var filteredApps: [AppInfo] {
        guard !search.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.bundleID.localizedCaseInsensitiveContains(search)
        }
    }

    private func badge(for app: AppInfo) -> some View {
        Text(app.clonabilityBadge)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(badgeColor(for: app).opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor(for: app))
    }

    private func badgeColor(for app: AppInfo) -> Color {
        switch app.recommendedStrategy {
        case .electronLauncher, .electronFullClone: return .green
        case .nativeRewrite: return .orange
        case .unsupported: return .red
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            selectPath(url.path)
        }
    }

    private func select(_ app: AppInfo) {
        selectPath(app.appPath)
    }

    private func selectPath(_ path: String) {
        isInspecting = true
        Task.detached {
            let result = Result { try AppInspector.inspect(appAt: path) }
            await MainActor.run {
                isInspecting = false
                switch result {
                case .success(let info):
                    selectedApp = info
                    cloneName = "\(info.name) 2"
                    strategy = info.recommendedStrategy == .unsupported
                        ? .unsupported
                        : info.recommendedStrategy
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Step 2: configure and create

    private func configure(_ app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.appPath))
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text(app.name).font(.title3.weight(.semibold))
                    Text(appKindDescription(app))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Back") { selectedApp = nil }
            }

            Divider()

            if app.recommendedStrategy == .unsupported {
                Label {
                    Text(CloneStrategy.unsupported.caveat)
                } icon: {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                }
                .font(.callout)
                Spacer()
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                }
            } else {
                TextField("Clone name", text: $cloneName)
                    .textFieldStyle(.roundedBorder)

                if app.fullCloneSupported {
                    Picker("Clone type", selection: $strategy) {
                        Text(CloneStrategy.electronLauncher.label).tag(CloneStrategy.electronLauncher)
                        Text(CloneStrategy.electronFullClone.label).tag(CloneStrategy.electronFullClone)
                    }
                    .pickerStyle(.radioGroup)
                } else if (app.isElectron || app.isChromiumBrowser) && app.hasAsarIntegrity {
                    Label("This app enforces integrity checks, so a full copy can't be re-signed without it refusing to launch. Launcher mode is used — it still gives the clone its own account.",
                          systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label {
                    Text(strategy.caveat)
                } icon: {
                    Image(systemName: strategy == .nativeRewrite
                          ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundStyle(strategy == .nativeRewrite ? .orange : .blue)
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                if app.prohibitsMultipleInstances && strategy == .nativeRewrite {
                    Text("This app prohibits multiple instances of itself, but the clone has its own identity, so both can usually still run together.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Nothing here bypasses an app's server-side device or session limits, and cloning may be restricted by an app's terms of service.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button {
                        create(app)
                    } label: {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Create Clone")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || cloneName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding()
    }

    private func appKindDescription(_ app: AppInfo) -> String {
        if app.isElectron { return "Electron app — fully cloneable with an isolated profile" }
        if app.isChromiumBrowser { return "Chromium browser — fully cloneable with an isolated profile" }
        if app.isMAS { return "Mac App Store app" }
        if app.entitlementsChecked && app.isSandboxed { return "Sandboxed app" }
        return "Native app — best-effort cloning"
    }

    private func create(_ app: AppInfo) {
        isWorking = true
        let name = cloneName
        let chosen = strategy
        Task.detached {
            let result = Result { try CloneEngine.create(from: app, name: name, strategy: chosen) }
            await MainActor.run {
                isWorking = false
                switch result {
                case .success(let clone):
                    store.add(clone)
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

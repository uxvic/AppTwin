import SwiftUI
import AppKit

struct CloneDetailView: View {
    @EnvironmentObject private var store: CloneStore
    let clone: Clone
    var onDeleted: () -> Void = {}

    @State private var isWorking = false
    @State private var showDeleteConfirm = false
    @State private var alsoDeleteData = true
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: iconSource))
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(clone.name).font(.title2.weight(.semibold))
                    Text("Clone of \(clone.sourceName)")
                        .foregroundStyle(.secondary)
                    Text(clone.strategy.label)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    run { try CloneEngine.launch(clone) }
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: clone.launcherAppPath)])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                if !clone.dataDir.isEmpty {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: clone.dataDir))
                    } label: {
                        Label("Open Data Folder", systemImage: "internaldrive")
                    }
                }

                if clone.strategy == .electronFullClone || clone.strategy == .nativeRewrite {
                    Button {
                        run {
                            try CloneEngine.resync(clone)
                            await MainActor.run { statusMessage = "Re-synced from the original app." }
                        }
                    } label: {
                        Label("Re-sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("Rebuild this clone from the current version of the original app (keeps your data)")
                }

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .disabled(isWorking)

            if isWorking { ProgressView() }
            if let status = statusMessage {
                Text(status).font(.callout).foregroundStyle(.green)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                infoRow("Source app", clone.sourceAppPath)
                infoRow("Source bundle ID", clone.sourceBundleID)
                infoRow("Clone bundle ID", clone.cloneBundleID)
                infoRow("Clone app", clone.launcherAppPath)
                if !clone.dataDir.isEmpty {
                    infoRow("Isolated data", clone.dataDir)
                }
                infoRow("Created", clone.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.callout)

            Label {
                Text(clone.strategy.caveat)
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(20)
        .alert("Something went wrong", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Delete “\(clone.name)”?", isPresented: $showDeleteConfirm) {
            Button("Delete Clone and Its Data", role: .destructive) {
                deleteClone(removeData: true)
            }
            Button("Delete Clone, Keep Data", role: .destructive) {
                deleteClone(removeData: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting the data removes the clone's separate login and settings.")
        }
    }

    private var iconSource: String {
        FileManager.default.fileExists(atPath: clone.launcherAppPath)
            ? clone.launcherAppPath
            : clone.sourceAppPath
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).textSelection(.enabled)
        }
    }

    private func run(_ work: @escaping @Sendable () async throws -> Void) {
        isWorking = true
        statusMessage = nil
        Task.detached {
            do {
                try await work()
                await MainActor.run { isWorking = false }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteClone(removeData: Bool) {
        let target = clone
        isWorking = true
        Task.detached {
            let result = Result { try CloneEngine.delete(target, removeData: removeData) }
            await MainActor.run {
                isWorking = false
                switch result {
                case .success:
                    store.remove(target)
                    onDeleted()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

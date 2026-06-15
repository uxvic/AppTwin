import SwiftUI
import AppKit

struct CloneListView: View {
    @EnvironmentObject private var store: CloneStore
    @State private var selection: Clone.ID?
    @State private var showNewClone = false

    var body: some View {
        NavigationSplitView {
            List(store.clones, selection: $selection) { clone in
                CloneRow(clone: clone)
                    .tag(clone.id)
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            .overlay {
                if store.clones.isEmpty { emptyState }
            }
        } detail: {
            if let id = selection, let clone = store.clones.first(where: { $0.id == id }) {
                CloneDetailView(clone: clone, onDeleted: { selection = nil })
            } else {
                ContentUnavailableCompat()
            }
        }
        .navigationTitle("AppTwin")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewClone = true
                } label: {
                    Label("New Clone", systemImage: "plus")
                }
                .help("Clone an installed app")
            }
        }
        .sheet(isPresented: $showNewClone) {
            NewCloneView()
                .environmentObject(store)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No clones yet")
                .font(.headline)
            Text("Clone an app to run it twice with separate accounts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Clone an App…") { showNewClone = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding()
    }
}

struct CloneRow: View {
    let clone: Clone

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: iconSource))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(clone.name)
                    .fontWeight(.medium)
                Text("from \(clone.sourceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                try? CloneEngine.launch(clone)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help("Launch \(clone.name)")
        }
        .padding(.vertical, 2)
    }

    private var iconSource: String {
        FileManager.default.fileExists(atPath: clone.launcherAppPath)
            ? clone.launcherAppPath
            : clone.sourceAppPath
    }
}

/// Minimal stand-in for ContentUnavailableView (macOS 14+) so we can target 13.
struct ContentUnavailableCompat: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.on.square")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Select a clone")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import Foundation

@MainActor
final class CloneStore: ObservableObject {
    @Published private(set) var clones: [Clone] = []

    init() {
        load()
    }

    func add(_ clone: Clone) {
        clones.append(clone)
        save()
    }

    func remove(_ clone: Clone) {
        clones.removeAll { $0.id == clone.id }
        save()
    }

    func load() {
        guard let data = try? Data(contentsOf: AppTwinPaths.storeFile) else { return }
        if let decoded = try? JSONDecoder().decode([Clone].self, from: data) {
            clones = decoded
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: AppTwinPaths.appSupport,
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(clones).write(to: AppTwinPaths.storeFile)
        } catch {
            NSLog("AppTwin: failed to save clone store: \(error)")
        }
    }
}

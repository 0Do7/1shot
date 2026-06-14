import Foundation

/// Watches folders for filesystem changes and reports the changed folder so a consumer
/// can re-scan it (spec §9.6 live watch). Injectable so the auto-import CONTROLLER is
/// headless-testable with a fake that fires synthetic events — no real FSEvents, no
/// permissions, deterministic. The real adapter (`DispatchSourceFolderWatcher`) is thin.
///
/// Contract: `start` begins delivering `onChange(folderPath)` callbacks; `stop` ends
/// them and releases all OS resources (so disabling auto-import truly stops watching).
public protocol FileSystemWatching: AnyObject, Sendable {
    /// Begin watching `folders`; `onChange` fires with a changed folder's path. The
    /// callback may run on an arbitrary queue, so consumers hop to their own actor.
    func start(folders: [String], onChange: @escaping @Sendable (String) -> Void)
    /// Stop watching and release every OS handle. Idempotent.
    func stop()
}

/// Production `FileSystemWatching`: one `DispatchSource` file-system-object monitor per
/// folder (`.write` on the directory vnode fires when entries are added/removed). Thin
/// by design — the import logic lives in `AutoImportController`/`AutoImporter`, this only
/// translates vnode events into "this folder changed". READ-ONLY: it opens directory
/// descriptors for event monitoring and never writes.
public final class DispatchSourceFolderWatcher: FileSystemWatching, @unchecked Sendable {
    // @unchecked: all mutable state (`sources`) is confined to `queue`; every access is
    // dispatched there, so there is no concurrent access despite the mutable stored array.
    private let queue = DispatchQueue(label: "com.sidequests.oneshot.library.autoimport.watch")
    private var sources: [DispatchSourceFileSystemObject] = []

    public init() {}

    public func start(folders: [String], onChange: @escaping @Sendable (String) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            tearDownLocked()
            for folder in folders {
                guard let source = Self.makeSource(folder: folder, queue: queue, onChange: onChange) else { continue }
                sources.append(source)
                source.resume()
            }
        }
    }

    public func stop() {
        queue.async { [weak self] in self?.tearDownLocked() }
    }

    deinit { tearDownLocked() }

    /// Cancel + drop every source. Must run on `queue` (or deinit, where no other
    /// access races). Cancelling closes the underlying descriptor via the cancel handler.
    private func tearDownLocked() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    private static func makeSource(
        folder: String,
        queue: DispatchQueue,
        onChange: @escaping @Sendable (String) -> Void
    ) -> DispatchSourceFileSystemObject? {
        let descriptor = open(folder, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { onChange(folder) }
        source.setCancelHandler { close(descriptor) }
        return source
    }
}

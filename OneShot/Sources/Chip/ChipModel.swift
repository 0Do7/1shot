import CoreGraphics
import Foundation
import OneShotCapture
import OneShotCore

/// A capture awaiting the user's decision. It exists only in memory — no
/// user-facing file is created for it until an explicit persisting action
/// (spec:post-capture-chip "Nothing written to disk until decided").
struct PendingCapture: Identifiable {
    let id: UUID
    let frame: CapturedFrame
    /// True once the user explicitly saved this capture to a file. The chip
    /// reflects the saved state but stays until dismissed.
    var isSaved = false
}

/// The three keys the chip's keyboard contract claims while armed
/// (spec:post-capture-chip "Keyboard contract"). Every other key passes through
/// to the frontmost app untouched.
enum ChipKey: Equatable {
    case discard // Esc
    case copy // ⌘C
    case expand // Enter / ↩

    /// Pure classification from a key event's raw fields, so the contract is
    /// testable without AppKit. `characters` is the event's character payload.
    static func from(keyCode: UInt16, hasCommand: Bool, characters: String?) -> ChipKey? {
        switch keyCode {
        case 53: return .discard // Escape
        case 36, 76: return .expand // Return, keypad Enter
        default:
            // ⌘C is only the copy contract when Command is held; a bare "c"
            // must reach the user's app (it is not a contracted key).
            if hasCommand, characters?.lowercased() == "c" { return .copy }
            return nil
        }
    }
}

/// The in-memory stack of undecided captures and the keyboard-contract state
/// machine (tasks 4.1, 4.2, 4.5). All AppKit/clipboard/file/editor effects are
/// injected as closures so this whole model is unit-testable headlessly — the
/// `ChipPresenter` supplies the real side-effects.
///
/// Ordering: `items` is oldest-first; the newest capture (`items.last`) is the
/// keyboard contract's target, matching the spec ("contract applies to the most
/// recent chip"). Timers live in the presenter, which calls `expireArming` and
/// `fireTimeout` — the model itself has no clock so tests drive it directly.
@MainActor
final class ChipStackModel {
    private(set) var items: [PendingCapture] = []
    /// The chip currently honoring the Esc/⌘C/Enter contract, or nil when the
    /// arming window has elapsed (the "keys live" affordance follows this).
    private(set) var armedItemID: UUID?

    // Injected side-effects.
    var onCopy: (PendingCapture) -> Void = { _ in }
    var onCopyAll: ([PendingCapture]) -> Void = { _ in }
    var onSave: (PendingCapture) -> Void = { _ in }
    var onPin: (PendingCapture) -> Void = { _ in }
    var onExpand: (PendingCapture) -> Void = { _ in }
    /// Fired after any mutation so the presenter re-lays-out the visible stack.
    var onChange: () -> Void = {}

    private let settings: () -> AppSettings

    init(settings: @escaping () -> AppSettings) {
        self.settings = settings
    }

    var armedItem: PendingCapture? {
        guard let armedItemID else { return nil }
        return items.first { $0.id == armedItemID }
    }

    // MARK: Intake

    /// Push a freshly captured frame. The keyboard contract re-arms on this new
    /// chip (the most recent one) when the contract is enabled.
    @discardableResult
    func add(_ frame: CapturedFrame) -> PendingCapture {
        let item = PendingCapture(id: UUID(), frame: frame)
        items.append(item)
        if settings().chipKeyboardContractEnabled {
            armedItemID = item.id
        }
        onChange()
        return item
    }

    // MARK: Keyboard contract

    /// Route a contract key to the armed chip. Returns `true` when the key was
    /// consumed (the event must be swallowed); `false` means it was not armed
    /// and the key must pass through to the frontmost app.
    @discardableResult
    func handleKey(_ key: ChipKey) -> Bool {
        guard settings().chipKeyboardContractEnabled, let armed = armedItem else { return false }
        switch key {
        case .discard: discard(armed.id)
        case .copy: copy(armed.id)
        case .expand: expand(armed.id)
        }
        return true
    }

    /// The arming window elapsed for `id`: keys return to the user, the chip
    /// stays per its timeout rules (spec: "Contract expires and keys return").
    func expireArming(_ id: UUID) {
        guard armedItemID == id else { return }
        armedItemID = nil
        onChange()
    }

    // MARK: Per-chip actions

    func copy(_ id: UUID) {
        guard let item = remove(id) else { return }
        onCopy(item)
    }

    /// Discard: drop the chip with nothing written to disk and nothing copied.
    func discard(_ id: UUID) {
        _ = remove(id)
    }

    func expand(_ id: UUID) {
        guard let item = remove(id) else { return }
        onExpand(item)
    }

    func pin(_ id: UUID) {
        guard let item = remove(id) else { return }
        onPin(item)
    }

    /// Save writes the file but keeps the chip, which now shows a saved badge
    /// (spec: "the chip reflects the saved state").
    func save(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSaved = true
        onSave(items[index])
        onChange()
    }

    // MARK: Bulk actions (stack)

    func copyAll() {
        guard !items.isEmpty else { return }
        let all = items
        items.removeAll()
        armedItemID = nil
        onCopyAll(all)
        onChange()
    }

    func saveAll() {
        guard !items.isEmpty else { return }
        for index in items.indices {
            items[index].isSaved = true
            onSave(items[index])
        }
        onChange()
    }

    /// Dismiss every chip, discarding all undecided captures with nothing
    /// written to disk (spec: "Bulk dismiss").
    func dismissAll() {
        guard !items.isEmpty else { return }
        items.removeAll()
        armedItemID = nil
        onChange()
    }

    // MARK: Timeout

    /// The auto-dismiss timeout elapsed for `id`. The configured action fires,
    /// then the chip is always removed (a timeout dismisses regardless).
    func fireTimeout(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch settings().chipTimeoutAction {
        case .discard:
            break
        case .copy:
            onCopy(items[index])
        case .save:
            items[index].isSaved = true
            onSave(items[index])
        }
        _ = remove(id)
    }

    // MARK: Private

    @discardableResult
    private func remove(_ id: UUID) -> PendingCapture? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let item = items.remove(at: index)
        if armedItemID == id { armedItemID = nil }
        onChange()
        return item
    }
}

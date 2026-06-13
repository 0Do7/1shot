import OneShotCore

/// A previously captured area, stored as the source display + display-local
/// native pixels so it can be recaptured exactly as long as that display is
/// still attached (spec:capture-engine "Repeat-previous-area").
struct AreaRegion: Codable, Hashable {
    var displayID: UInt32
    var pixels: PixelRect
}

/// What repeat-area capture should do given the current display arrangement.
enum RepeatDecision: Equatable {
    case recapture(AreaRegion)
    case fallbackToArea
}

/// Remembers the last area selection and decides repeat-area behavior (spec
/// scenarios: recapture the exact same region; fall back to normal area
/// selection when no prior region exists or its display has detached). The
/// `load`/`save` closures inject persistence (UserDefaults in the app); the
/// decision itself is a pure static so it is unit-testable without storage.
@MainActor
final class RepeatAreaModel {
    private(set) var lastRegion: AreaRegion?

    private let save: (AreaRegion?) -> Void

    init(load: () -> AreaRegion? = { nil }, save: @escaping (AreaRegion?) -> Void = { _ in }) {
        self.save = save
        lastRegion = load()
    }

    func record(displayID: UInt32, pixels: PixelRect) {
        let region = AreaRegion(displayID: displayID, pixels: pixels)
        lastRegion = region
        save(region)
    }

    func decision(in layout: DisplayLayout) -> RepeatDecision {
        Self.decision(for: lastRegion, in: layout)
    }

    nonisolated static func decision(for region: AreaRegion?, in layout: DisplayLayout) -> RepeatDecision {
        guard let region, layout.display(withID: region.displayID) != nil else {
            return .fallbackToArea
        }
        return .recapture(region)
    }
}

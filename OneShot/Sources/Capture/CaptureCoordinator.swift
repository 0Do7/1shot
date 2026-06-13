import AppKit
import OneShotCapture
import OneShotCore

/// Routes a triggered `BindableAction` (hotkey or menu) to the right capture
/// flow and emits the resulting frame (task 3.4, spec:capture-engine "Capture
/// modes"). Area + freeze reuse `AreaSelectionController` (3.2); window reuses
/// the 3.3 pick UX via `WindowPickController`; fullscreen/repeat/delayed are
/// implemented here. Output routing (chip, Library, destinations) is a later
/// wave — this layer's contract ends at producing a `CapturedFrame`.
@MainActor
final class CaptureCoordinator {
    private let still: StillCaptureService
    private let settings: () -> AppSettings
    private let repeatModel: RepeatAreaModel
    private var isCapturing = false

    var onCapture: ((CapturedFrame) -> Void)?
    var onError: ((CaptureError) -> Void)?

    init(
        still: StillCaptureService = StillCaptureService(),
        repeatModel: RepeatAreaModel,
        settings: @escaping () -> AppSettings
    ) {
        self.still = still
        self.repeatModel = repeatModel
        self.settings = settings
    }

    /// Entry point from `HotkeyCenter.onAction` and the menu bar.
    func handle(_ action: BindableAction) {
        guard let mode = CaptureModeCatalog.mode(for: action) else { return }
        Task { await perform(mode) }
    }

    func perform(_ mode: CaptureMode) async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            switch mode {
            case .area, .freezeScreen: try await captureArea()
            case .window: try await captureWindow()
            case .fullscreen: try await captureFullscreen()
            case .repeatArea: try await captureRepeat()
            case .delayed: try await captureDelayed()
            case .scrolling: break // §7 lane
            }
        } catch let error as CaptureError {
            onError?(error)
        } catch {
            onError?(CaptureError(wrapping: error))
        }
    }

    // MARK: Flows

    private func captureArea() async throws {
        let controller = AreaSelectionController(still: still)
        if case let .captured(frame) = try await controller.begin(options: options()) {
            repeatModel.record(displayID: frame.displayID, pixels: frame.pixels)
            onCapture?(frame)
        }
    }

    private func captureWindow() async throws {
        guard let window = try await WindowPickController().begin() else { return }
        let frame = try await still.captureWindow(
            window,
            shadow: settings().windowCaptureShadow,
            options: options()
        )
        onCapture?(frame)
    }

    private func captureFullscreen() async throws {
        let layout = try await ShareableContentService.snapshot().layout
        guard let display = CaptureTargeting.fullscreenDisplay(in: layout, cursor: currentCursor()) else {
            throw CaptureError.displayNotFound(0)
        }
        try await onCapture?(still.captureFullDisplay(display, options: options()))
    }

    private func captureRepeat() async throws {
        let layout = try await ShareableContentService.snapshot().layout
        switch repeatModel.decision(in: layout) {
        case .fallbackToArea:
            try await captureArea()
        case let .recapture(region):
            guard let display = layout.display(withID: region.displayID) else {
                try await captureArea()
                return
            }
            guard await RepeatPreviewOverlay().show(region: region.pixels, on: display) else { return }
            try await onCapture?(still.capture(display: display, pixels: region.pixels, options: options()))
        }
    }

    private func captureDelayed() async throws {
        guard await CountdownOverlay().run(seconds: settings().delayedCaptureSeconds) else { return }
        try await captureFullscreen()
    }

    // MARK: Helpers

    private func options() -> CaptureOptions {
        CaptureOptions(includeCursor: settings().includeCursor)
    }

    private func currentCursor() -> LogicalPoint {
        let location = NSEvent.mouseLocation
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        return WindowPickerGeometry.logicalPoint(forAppKit: location, primaryScreenHeight: primaryHeight)
    }
}

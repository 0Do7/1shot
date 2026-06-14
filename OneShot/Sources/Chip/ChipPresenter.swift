import AppKit
import Foundation
import OneShotCapture
import OneShotCore
import OneShotDestinations

/// Owns the live chip stack: panels, the keyboard-contract monitor, arm/timeout
/// timers, and the real side-effects (clipboard, file save, editor/pin hand-off).
/// The decision logic lives in `ChipStackModel`; this is the AppKit shell that
/// wires it to the screen and the system. Replaces `AppDelegate`'s clipboard
/// placeholder as the capture output sink (tasks 4.1–4.5).
@MainActor
final class ChipPresenter {
    let model: ChipStackModel

    /// Open the full editor seeded with this capture (§5). Until the editor
    /// lane lands, the app supplies an honest placeholder window.
    var openEditor: (CapturedFrame) -> Void = { _ in }
    /// Float this capture as an always-on-top pin (§10.5). App supplies it.
    var openPin: (CapturedFrame) -> Void = { _ in }

    private let settings: () -> AppSettings
    private let contractMonitor: ChipContractMonitoring
    private let chipSize = NSSize(width: 248, height: 150)

    private var panels: [UUID: ChipPanel] = [:]
    private var armTasks: [UUID: Task<Void, Never>] = [:]
    private var timeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var toast: ChipToast?

    init(
        settings: @escaping () -> AppSettings,
        contractMonitor: ChipContractMonitoring = CGEventTapContractMonitor()
    ) {
        self.settings = settings
        self.contractMonitor = contractMonitor
        model = ChipStackModel(settings: settings)
        wireModel()
    }

    /// Capture output entry point (called by `AppDelegate`).
    func present(_ frame: CapturedFrame) {
        guard settings().chipEnabled else {
            // Chip-off (pure clipboard) mode: copy + a brief, non-focus-stealing
            // toast, no chip, no file (spec: "Chip-off (pure clipboard) mode").
            writeToClipboard(frame)
            showToast("Copied to clipboard", on: frame.displayID)
            return
        }
        let item = model.add(frame)
        scheduleArmExpiry(for: item.id)
        scheduleTimeout(for: item.id)
    }

    // MARK: Model wiring

    private func wireModel() {
        model.onChange = { [weak self] in self?.relayout() }
        model.onCopy = { [weak self] in self?.writeToClipboard($0.frame) }
        model.onCopyAll = { [weak self] in self?.writeToClipboard($0.map(\.frame)) }
        model.onSave = { [weak self] in self?.saveToFile($0.frame) }
        model.onPin = { [weak self] in self?.openPin($0.frame) }
        model.onExpand = { [weak self] in self?.openEditor($0.frame) }
    }

    private func perform(_ action: ChipAction, on id: UUID) {
        switch action {
        case .copy: model.copy(id)
        case .save: model.save(id)
        case .pin: model.pin(id)
        case .edit: model.expand(id)
        }
    }

    // MARK: Layout

    private func relayout() {
        let items = model.items
        let liveIDs = Set(items.map(\.id))
        for (id, panel) in panels where !liveIDs.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
            cancelTimers(for: id)
        }
        updateContractMonitor()

        let corner = settings().chipCorner
        // items is oldest-first; the newest (last) hugs the corner at index 0.
        for (indexFromNewest, item) in items.reversed().enumerated() {
            let panel = panels[item.id] ?? makePanel(for: item)
            panels[item.id] = panel
            (panel.contentView as? ChipView)?.update(
                isArmed: model.armedItemID == item.id,
                isSaved: item.isSaved
            )
            let frame = ChipLayout.frame(
                for: corner,
                displayFrame: screen(for: item.frame.displayID).visibleFrame,
                chipSize: chipSize,
                stackIndex: indexFromNewest
            )
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel(for item: PendingCapture) -> ChipPanel {
        let panel = ChipPanel(contentRect: NSRect(origin: .zero, size: chipSize))
        let view = ChipView(
            frame: NSRect(origin: .zero, size: chipSize),
            capture: item,
            suggestedName: dragFileName()
        )
        view.onAction = { [weak self] action in self?.perform(action, on: item.id) }
        panel.contentView = view
        return panel
    }

    // MARK: Keyboard contract

    private func updateContractMonitor() {
        if model.armedItem != nil {
            contractMonitor.start { [weak self] key in self?.model.handleKey(key) ?? false }
        } else {
            contractMonitor.stop()
        }
    }

    // MARK: Timers (cancellable Tasks — the codebase's Swift-6 timing idiom)

    private func scheduleArmExpiry(for id: UUID) {
        guard settings().chipKeyboardContractEnabled else { return }
        let seconds = settings().chipKeyboardArmSeconds
        guard seconds > 0 else { return }
        armTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.model.expireArming(id)
        }
    }

    private func scheduleTimeout(for id: UUID) {
        let seconds = settings().chipTimeoutSeconds
        guard seconds > 0 else { return } // 0 = persistent (no auto-dismiss)
        timeoutTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.model.fireTimeout(id)
        }
    }

    private func cancelTimers(for id: UUID) {
        armTasks[id]?.cancel()
        armTasks[id] = nil
        timeoutTasks[id]?.cancel()
        timeoutTasks[id] = nil
    }

    // MARK: Side-effects

    private func writeToClipboard(_ frames: [CapturedFrame]) {
        let images = frames.map { NSImage(cgImage: $0.image, size: pixelSize($0)) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(images)
    }

    private func writeToClipboard(_ frame: CapturedFrame) {
        writeToClipboard([frame])
    }

    private func saveToFile(_ frame: CapturedFrame) {
        let current = settings()
        guard let preset = OutputPresetResolver.preset(
            forCaptureType: "image",
            presets: current.presets,
            routing: current.routing
        ) else { return }
        let defaultPreset = current.presets.first { $0.id == current.routing.defaultPresetID } ?? preset
        let resolved = OutputPresetResolver.resolveSaveLocation(for: preset, defaultPreset: defaultPreset) { path in
            var isDir: ObjCBool = false
            let expanded = (path as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
        }
        let context = TemplateContext(date: Date(), captureType: "image")
        let fileName = FilenameTemplate.render(preset.template, context: context) + "." + preset.format.pathExtension
        guard let data = try? ImageEncoder.encode(
            frame.image,
            format: preset.format,
            options: ImageEncoder.Options(downscaleRetinaTo1x: preset.downscaleRetinaTo1x, sourceScale: frame.scale)
        ) else { return }
        let payload = DestinationPayload.image(data: data, utType: preset.format.utType, suggestedFileName: fileName)
        let configuration: DestinationConfiguration = [FileDestination.configDirectoryKey: resolved.directoryPath]
        Task {
            do {
                _ = try await FileDestination().deliver(payload, configuration: configuration)
            } catch {
                NSLog("1shot: chip save failed: \(String(describing: error))")
            }
        }
    }

    private func showToast(_ message: String, on displayID: UInt32) {
        toast?.dismiss()
        let toast = ChipToast(message: message, corner: settings().chipCorner, screen: screen(for: displayID))
        toast.show()
        self.toast = toast
    }

    // MARK: Helpers

    private func dragFileName() -> String {
        let template = settings().presets.first?.template ?? FilenameTemplate.defaultTemplate
        let base = FilenameTemplate.render(template, context: TemplateContext(date: Date(), captureType: "image"))
        return base + "." + ImageFormat.png.pathExtension
    }

    private func pixelSize(_ frame: CapturedFrame) -> NSSize {
        NSSize(width: frame.image.width, height: frame.image.height)
    }

    private func screen(for displayID: UInt32) -> NSScreen {
        NSScreen.screens.first { $0.oneShotDisplayID == displayID } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

/// A minimal non-activating confirmation used by chip-off mode (spec: "minimal
/// non-focus-stealing confirmation"). Auto-dismisses.
@MainActor
final class ChipToast {
    private let panel: ChipPanel
    private var dismissTask: Task<Void, Never>?

    init(message: String, corner: ScreenCorner, screen: NSScreen) {
        let size = NSSize(width: 200, height: 44)
        let frame = ChipLayout.frame(for: corner, displayFrame: screen.visibleFrame, chipSize: size, stackIndex: 0)
        panel = ChipPanel(contentRect: frame)
        let label = NSTextField(labelWithString: message)
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        container.layer?.cornerRadius = 10
        label.frame = container.bounds
        label.autoresizingMask = [.width, .height]
        container.addSubview(label)
        container.setAccessibilityElement(true)
        container.setAccessibilityLabel(message)
        panel.contentView = container
    }

    func show() {
        panel.orderFrontRegardless()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        panel.orderOut(nil)
    }
}

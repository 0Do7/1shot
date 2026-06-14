import AppKit
import OneShotCapture
import OneShotCore

/// Menu-bar shell (design D1). Wires global hotkeys + the menu-bar menu to the
/// capture coordinator (task 3.4), and routes every capture into the
/// post-capture chip (§4), which owns copy/save/pin/edit and the keyboard
/// contract. The editor (§5) and pin (§10.5) lanes plug into the presenter's
/// `openEditor`/`openPin` seams — placeholder windows stand in until they land.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyCenter: HotkeyCenter?
    private var coordinator: CaptureCoordinator?
    private var chipPresenter: ChipPresenter?
    private var seamWindows: [NSWindow] = []

    private static let repeatRegionKey = "oneShot.lastAreaRegion"

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Settings persistence is task 13.3; until then the opinionated defaults
        // drive hotkeys, delay, and capture options.
        let settings = AppSettings()

        let presenter = ChipPresenter(settings: { AppSettings() })
        presenter.openEditor = { [weak self] frame in self?.openPlaceholderEditor(frame) }
        presenter.openPin = { [weak self] frame in self?.openPlaceholderPin(frame) }
        chipPresenter = presenter

        let repeatModel = RepeatAreaModel(load: Self.loadRegion, save: Self.saveRegion)
        let coordinator = CaptureCoordinator(repeatModel: repeatModel, settings: { AppSettings() })
        coordinator.onCapture = { [weak self] frame in self?.chipPresenter?.present(frame) }
        coordinator.onError = { error in NSLog("1shot capture error: \(String(describing: error))") }
        self.coordinator = coordinator

        let center = HotkeyCenter(registrar: CarbonHotkeyRegistrar())
        center.onAction = { [weak coordinator] action in coordinator?.handle(action) }
        let failures = center.apply(settings.hotkeys)
        if !failures.isEmpty {
            NSLog("1shot: some hotkeys could not be registered: \(failures.keys.map(\.rawValue))")
        }
        hotkeyCenter = center

        installStatusItem()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "1shot"
        )

        let menu = NSMenu()
        for entry in CaptureModeCatalog.entries {
            let menuItem = NSMenuItem(
                title: entry.title,
                action: #selector(captureMenuItem(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = entry.action.rawValue
            menuItem.target = self
            menu.addItem(menuItem)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit 1shot",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu
        statusItem = item
    }

    @objc private func captureMenuItem(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = BindableAction(rawValue: raw) else { return }
        coordinator?.handle(action)
    }

    // MARK: Editor / pin seams (replaced by §5 and §10.5)

    /// §5 seam: the real annotation editor (OneShotRender canvas) replaces this.
    /// Until then, opening the capture in a focused window keeps capture → chip →
    /// editor observable end-to-end and lets the chip's expand contract be verified.
    private func openPlaceholderEditor(_ frame: CapturedFrame) {
        presentSeamWindow(frame, title: "1shot — Editor (preview · §5)", activates: true, floating: false)
    }

    /// §10.5 seam: real pin adds per-pin opacity, click-through lock, and
    /// scroll-resize. The minimal always-on-top window stands in for now.
    private func openPlaceholderPin(_ frame: CapturedFrame) {
        presentSeamWindow(frame, title: "1shot — Pinned", activates: false, floating: true)
    }

    private func presentSeamWindow(_ frame: CapturedFrame, title: String, activates: Bool, floating: Bool) {
        let pixels = NSSize(width: frame.image.width, height: frame.image.height)
        let scale = min(1, 900 / max(pixels.width, pixels.height))
        let size = NSSize(width: pixels.width * scale, height: pixels.height * scale)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: floating ? [.borderless] : [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        if floating { window.level = .floating }
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.image = NSImage(cgImage: frame.image, size: pixels)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        window.contentView = imageView
        window.center()
        seamWindows.append(window)
        if activates {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    private static func loadRegion() -> AreaRegion? {
        guard let data = UserDefaults.standard.data(forKey: repeatRegionKey) else { return nil }
        return try? JSONDecoder().decode(AreaRegion.self, from: data)
    }

    private static func saveRegion(_ region: AreaRegion?) {
        guard let region, let data = try? JSONEncoder().encode(region) else {
            UserDefaults.standard.removeObject(forKey: repeatRegionKey)
            return
        }
        UserDefaults.standard.set(data, forKey: repeatRegionKey)
    }
}

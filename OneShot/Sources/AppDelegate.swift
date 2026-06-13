import AppKit
import OneShotCapture
import OneShotCore

/// Menu-bar shell (design D1). Wires global hotkeys + the menu-bar menu to the
/// capture coordinator (task 3.4). Capture output currently lands on the
/// clipboard as a placeholder sink; the post-capture chip, Library, and
/// destination routing (waves 2+) replace `handleCapture` without touching the
/// capture engine.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyCenter: HotkeyCenter?
    private var coordinator: CaptureCoordinator?

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

        let repeatModel = RepeatAreaModel(load: Self.loadRegion, save: Self.saveRegion)
        let coordinator = CaptureCoordinator(repeatModel: repeatModel, settings: { AppSettings() })
        coordinator.onCapture = { [weak self] frame in self?.handleCapture(frame) }
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

    /// Placeholder output: copy the capture to the clipboard so the engine is
    /// observable end-to-end before the chip/routing waves land.
    private func handleCapture(_ frame: CapturedFrame) {
        let image = NSImage(
            cgImage: frame.image,
            size: NSSize(width: frame.image.width, height: frame.image.height)
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        NSLog("1shot: captured \(frame.image.width)×\(frame.image.height) on display \(frame.displayID) → clipboard")
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

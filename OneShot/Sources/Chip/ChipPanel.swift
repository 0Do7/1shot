import AppKit
import OneShotCore
import OneShotDestinations
import UniformTypeIdentifiers

/// A hover affordance / contract action the chip view can request.
enum ChipAction {
    case copy
    case save
    case pin
    case edit
}

/// Non-activating panel that hosts a single chip (design D7). It floats above
/// all apps, follows the user across Spaces, and — critically — never becomes
/// key or main, so the frontmost app keeps focus and keystrokes while it shows
/// (spec: "Chip never steals focus").
final class ChipPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

/// The chip's content: a capture thumbnail with hover-revealed actions, a
/// "keys live" affordance while the contract is armed, and a saved badge.
/// Clicking the body edits; dragging starts a file-promise drag-out so the
/// image file is materialized only on an accepted drop (spec: "Drag-out as
/// file"). All controls expose VoiceOver labels (spec: "Chip accessibility").
final class ChipView: NSView, NSDraggingSource {
    var onAction: (ChipAction) -> Void = { _ in }

    private let image: NSImage
    private let cgImage: CGImage
    private let suggestedName: String

    private let thumbnail = NSImageView()
    private let actionBar = NSStackView()
    private let keysBadge = NSTextField(labelWithString: "esc · ⌘C · ↩")
    private let savedBadge = NSTextField(labelWithString: "Saved")
    private var trackingArea: NSTrackingArea?
    private var dragOrigin: NSPoint?

    init(frame: NSRect, capture: PendingCapture, suggestedName: String) {
        image = NSImage(cgImage: capture.frame.image, size: frame.size)
        cgImage = capture.frame.image
        self.suggestedName = suggestedName
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        setupThumbnail()
        setupActionBar()
        setupBadges()

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Capture preview. Press Return to edit, Command-C to copy, Escape to discard.")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    /// Show/hide the armed and saved affordances as the model state changes.
    func update(isArmed: Bool, isSaved: Bool) {
        keysBadge.isHidden = !isArmed
        savedBadge.isHidden = !isSaved
    }

    // MARK: Layout

    private func setupThumbnail() {
        thumbnail.image = image
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.frame = bounds.insetBy(dx: 6, dy: 6)
        thumbnail.autoresizingMask = [.width, .height]
        addSubview(thumbnail)
    }

    private func setupActionBar() {
        actionBar.orientation = .horizontal
        actionBar.spacing = 6
        actionBar.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        actionBar.wantsLayer = true
        actionBar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        actionBar.layer?.cornerRadius = 8
        actionBar.isHidden = true // revealed on hover

        addActionButton("doc.on.doc", label: "Copy", action: .copy)
        addActionButton("square.and.arrow.down", label: "Save", action: .save)
        addActionButton("pin", label: "Pin", action: .pin)
        addActionButton("pencil", label: "Edit", action: .edit)
        addActionButton("line.3.horizontal", label: "Drag out", action: nil) // drag handle

        actionBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionBar)
        NSLayoutConstraint.activate([
            actionBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            actionBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    private func addActionButton(_ symbol: String, label: String, action: ChipAction?) {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage(),
            target: self,
            action: #selector(actionButtonTapped(_:))
        )
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.contentTintColor = .white
        button.setAccessibilityLabel(label)
        button.tag = action.map(Self.tag(for:)) ?? -1
        actionBar.addArrangedSubview(button)
    }

    private func setupBadges() {
        for badge in [keysBadge, savedBadge] {
            badge.font = .systemFont(ofSize: 10, weight: .semibold)
            badge.textColor = .white
            badge.wantsLayer = true
            badge.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            badge.layer?.cornerRadius = 6
            badge.alignment = .center
            badge.isHidden = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            addSubview(badge)
        }
        savedBadge.layer?.backgroundColor = NSColor.systemGreen.cgColor
        NSLayoutConstraint.activate([
            keysBadge.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            keysBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            keysBadge.heightAnchor.constraint(equalToConstant: 16),
            keysBadge.widthAnchor.constraint(equalToConstant: 84),
            savedBadge.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            savedBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            savedBadge.heightAnchor.constraint(equalToConstant: 16),
            savedBadge.widthAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with _: NSEvent) {
        actionBar.isHidden = false
    }

    override func mouseExited(with _: NSEvent) {
        actionBar.isHidden = true
    }

    // MARK: Actions

    @objc private func actionButtonTapped(_ sender: NSButton) {
        guard let action = Self.action(for: sender.tag) else { return } // drag handle has no tap action
        onAction(action)
    }

    override func mouseUp(with event: NSEvent) {
        // A click on the body (not on a button) opens the editor.
        if event.clickCount == 1, dragOrigin == nil {
            onAction(.edit)
        }
        dragOrigin = nil
    }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
    }

    // MARK: Drag-out (file promise)

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin else { return }
        let distance = hypot(event.locationInWindow.x - dragOrigin.x, event.locationInWindow.y - dragOrigin.y)
        guard distance > 6 else { return }
        self.dragOrigin = nil
        beginFilePromiseDrag(with: event)
    }

    private func beginFilePromiseDrag(with event: NSEvent) {
        // Encode now on the main thread; the delegate writes the bytes only if
        // the drop is accepted, so a cancelled drag leaves nothing on disk.
        guard let data = try? ImageEncoder.encode(cgImage, format: .png) else { return }
        let delegate = ChipFilePromiseDelegate(data: data, fileName: suggestedName)
        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: delegate)
        let item = NSDraggingItem(pasteboardWriter: provider)
        let dragFrame = NSRect(origin: .zero, size: NSSize(width: 160, height: 100))
        item.setDraggingFrame(dragFrame, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    // MARK: Tag <-> action mapping (NSButton.tag is an Int)

    private static func tag(for action: ChipAction) -> Int {
        switch action {
        case .copy: 0
        case .save: 1
        case .pin: 2
        case .edit: 3
        }
    }

    private static func action(for tag: Int) -> ChipAction? {
        switch tag {
        case 0: .copy
        case 1: .save
        case 2: .pin
        case 3: .edit
        default: nil
        }
    }
}

/// Writes the promised PNG only when a drop pulls it. Holds the already-encoded
/// bytes (Sendable `Data`), so the off-main write touches no main-actor state.
final class ChipFilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    private let data: Data
    private let fileName: String
    private let queue = OperationQueue()

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        fileName
    }

    func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try data.write(to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        queue
    }
}

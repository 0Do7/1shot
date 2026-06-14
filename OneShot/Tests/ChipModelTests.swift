import CoreGraphics
import Foundation
import OneShotCapture
import OneShotCore
import Testing
@testable import OneShot

// MARK: Fixtures

@MainActor
private func makeFrame(displayID: UInt32 = 1) -> CapturedFrame {
    let context = CGContext(
        data: nil,
        width: 4,
        height: 4,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return CapturedFrame(
        type: .image,
        image: context.makeImage()!,
        displayID: displayID,
        pixels: PixelRect(x: 0, y: 0, width: 4, height: 4),
        scale: 2.0
    )
}

/// Records which side-effects the model fired, so action routing is observable.
@MainActor
private final class SideEffectSpy {
    var copied: [UUID] = []
    var copiedAll: [[UUID]] = []
    var saved: [UUID] = []
    var pinned: [UUID] = []
    var expanded: [UUID] = []
    var changes = 0

    func attach(to model: ChipStackModel) {
        model.onCopy = { [weak self] in self?.copied.append($0.id) }
        model.onCopyAll = { [weak self] in self?.copiedAll.append($0.map(\.id)) }
        model.onSave = { [weak self] in self?.saved.append($0.id) }
        model.onPin = { [weak self] in self?.pinned.append($0.id) }
        model.onExpand = { [weak self] in self?.expanded.append($0.id) }
        model.onChange = { [weak self] in self?.changes += 1 }
    }
}

@MainActor
private func makeModel(_ settings: @escaping () -> AppSettings) -> (ChipStackModel, SideEffectSpy) {
    let model = ChipStackModel(settings: settings)
    let spy = SideEffectSpy()
    spy.attach(to: model)
    return (model, spy)
}

// MARK: Intake + stacking (spec: Multi-capture stacking)

@MainActor @Test func add_armsContractOnNewestChip() {
    let (model, _) = makeModel { AppSettings() }
    let first = model.add(makeFrame())
    #expect(model.items.count == 1)
    #expect(model.armedItemID == first.id)

    let second = model.add(makeFrame())
    // Contract moves to the most recent chip.
    #expect(model.items.count == 2)
    #expect(model.armedItemID == second.id)
}

@MainActor @Test func threeRapidCaptures_stack() {
    let (model, _) = makeModel { AppSettings() }
    model.add(makeFrame())
    model.add(makeFrame())
    model.add(makeFrame())
    #expect(model.items.count == 3)
}

// MARK: Keyboard contract (spec: Keyboard contract)

@MainActor @Test func contract_escDiscardsNewest_nothingCopied() {
    let (model, spy) = makeModel { AppSettings() }
    model.add(makeFrame())
    let newest = model.add(makeFrame())

    #expect(model.handleKey(.discard))
    #expect(!model.items.contains { $0.id == newest.id })
    #expect(model.items.count == 1)
    #expect(spy.copied.isEmpty) // discard never touches the clipboard
}

@MainActor @Test func contract_cmdCCopiesAndDismisses() {
    let (model, spy) = makeModel { AppSettings() }
    let item = model.add(makeFrame())

    #expect(model.handleKey(.copy))
    #expect(spy.copied == [item.id])
    #expect(model.items.isEmpty)
    #expect(model.armedItemID == nil)
}

@MainActor @Test func contract_enterExpandsAndRemoves() {
    let (model, spy) = makeModel { AppSettings() }
    let item = model.add(makeFrame())

    #expect(model.handleKey(.expand))
    #expect(spy.expanded == [item.id])
    #expect(model.items.isEmpty)
}

@MainActor @Test func contract_expires_keysPassThrough() {
    let (model, spy) = makeModel { AppSettings() }
    let item = model.add(makeFrame())

    model.expireArming(item.id)
    #expect(model.armedItemID == nil)
    // After expiry the chip remains but the keys no longer belong to it.
    #expect(!model.handleKey(.copy))
    #expect(model.items.count == 1)
    #expect(spy.copied.isEmpty)
}

@MainActor @Test func contract_disabledInSettings_neverArmsOrSwallows() {
    var settings = AppSettings()
    settings.chipKeyboardContractEnabled = false
    let (model, _) = makeModel { settings }
    model.add(makeFrame())

    #expect(model.armedItemID == nil)
    #expect(!model.handleKey(.discard)) // passes through to the frontmost app
    #expect(model.items.count == 1)
}

// MARK: Individual vs bulk (spec: Individual action within a stack / Bulk dismiss)

@MainActor @Test func copyingMiddleChip_leavesTheOthers() {
    let (model, spy) = makeModel { AppSettings() }
    let first = model.add(makeFrame())
    let middle = model.add(makeFrame())
    let last = model.add(makeFrame())

    model.copy(middle.id)
    #expect(spy.copied == [middle.id])
    #expect(model.items.map(\.id) == [first.id, last.id])
}

@MainActor @Test func dismissAll_clearsEverythingWithNoCopy() {
    let (model, spy) = makeModel { AppSettings() }
    model.add(makeFrame())
    model.add(makeFrame())

    model.dismissAll()
    #expect(model.items.isEmpty)
    #expect(model.armedItemID == nil)
    #expect(spy.copied.isEmpty)
    #expect(spy.copiedAll.isEmpty)
}

@MainActor @Test func copyAll_copiesEveryChipThenClears() {
    let (model, spy) = makeModel { AppSettings() }
    let first = model.add(makeFrame())
    let second = model.add(makeFrame())

    model.copyAll()
    #expect(spy.copiedAll == [[first.id, second.id]])
    #expect(model.items.isEmpty)
}

// MARK: Save (spec: Save action prompts for destination behavior)

@MainActor @Test func save_writesFileButKeepsChip_markingSaved() {
    let (model, spy) = makeModel { AppSettings() }
    let item = model.add(makeFrame())

    model.save(item.id)
    #expect(spy.saved == [item.id])
    #expect(model.items.first?.isSaved == true)
    #expect(model.items.count == 1) // save does not dismiss
}

@MainActor @Test func pin_floatsAndDismissesChip() {
    let (model, spy) = makeModel { AppSettings() }
    let item = model.add(makeFrame())

    model.pin(item.id)
    #expect(spy.pinned == [item.id])
    #expect(model.items.isEmpty)
}

// MARK: Timeout (spec: Chip persistence and timeout)

@MainActor @Test func timeout_discardAction_dropsChipNoCopy() {
    var settings = AppSettings()
    settings.chipTimeoutAction = .discard
    let (model, spy) = makeModel { settings }
    let item = model.add(makeFrame())

    model.fireTimeout(item.id)
    #expect(model.items.isEmpty)
    #expect(spy.copied.isEmpty)
    #expect(spy.saved.isEmpty)
}

@MainActor @Test func timeout_copyAction_copiesThenDismisses() {
    var settings = AppSettings()
    settings.chipTimeoutAction = .copy
    let (model, spy) = makeModel { settings }
    let item = model.add(makeFrame())

    model.fireTimeout(item.id)
    #expect(spy.copied == [item.id])
    #expect(model.items.isEmpty)
}

@MainActor @Test func timeout_saveAction_savesThenDismisses() {
    var settings = AppSettings()
    settings.chipTimeoutAction = .save
    let (model, spy) = makeModel { settings }
    let item = model.add(makeFrame())

    model.fireTimeout(item.id)
    #expect(spy.saved == [item.id])
    #expect(model.items.isEmpty)
}

// MARK: Key classification

@Test func chipKey_classifiesContractKeys() {
    #expect(ChipKey.from(keyCode: 53, hasCommand: false, characters: "\u{1B}") == .discard)
    #expect(ChipKey.from(keyCode: 36, hasCommand: false, characters: "\r") == .expand)
    #expect(ChipKey.from(keyCode: 76, hasCommand: false, characters: "\r") == .expand)
    #expect(ChipKey.from(keyCode: 8, hasCommand: true, characters: "c") == .copy)
    #expect(ChipKey.from(keyCode: 8, hasCommand: true, characters: "C") == .copy)
}

@Test func chipKey_ignoresNonContractKeys() {
    #expect(ChipKey.from(keyCode: 8, hasCommand: false, characters: "c") == nil) // bare c → user's app
    #expect(ChipKey.from(keyCode: 0, hasCommand: true, characters: "a") == nil) // ⌘A → user's app
    #expect(ChipKey.from(keyCode: 49, hasCommand: false, characters: " ") == nil)
}

// MARK: Layout (spec: configurable corner / appears on the capture's display)

@Test func layout_anchorsAndStacksPerCorner() {
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 220, height: 130)

    let bottomTrailing = ChipLayout.frame(for: .bottomTrailing, displayFrame: display, chipSize: size, stackIndex: 0)
    #expect(bottomTrailing.maxX == display.maxX - ChipLayout.margin)
    #expect(bottomTrailing.minY == ChipLayout.margin)

    let topLeading = ChipLayout.frame(for: .topLeading, displayFrame: display, chipSize: size, stackIndex: 0)
    #expect(topLeading.minX == ChipLayout.margin)
    #expect(topLeading.maxY == display.maxY - ChipLayout.margin)

    // Bottom stacks upward, top stacks downward.
    let bottomSecond = ChipLayout.frame(for: .bottomTrailing, displayFrame: display, chipSize: size, stackIndex: 1)
    #expect(bottomSecond.minY > bottomTrailing.minY)
    let topSecond = ChipLayout.frame(for: .topLeading, displayFrame: display, chipSize: size, stackIndex: 1)
    #expect(topSecond.maxY < topLeading.maxY)
}

@Test func layout_placesChipWithinTheGivenDisplayFrame() {
    // A secondary display offset to the right — the chip lands on it, not (0,0).
    let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let size = CGSize(width: 220, height: 130)
    let frame = ChipLayout.frame(for: .bottomTrailing, displayFrame: secondary, chipSize: size, stackIndex: 0)
    #expect(secondary.contains(frame))
    #expect(frame.minX >= secondary.minX)
}

## ADDED Requirements

### Requirement: Pin creation from capture surfaces
The app SHALL allow pinning an image as a floating window from: the post-capture chip (hover action and keyboard shortcut), the editor, the Library, and a dedicated pin-last-capture path. A pin SHALL appear at the original on-screen position and size of the captured region by default, so the float visually replaces the captured content.

#### Scenario: Pin from the chip
- **WHEN** the user captures a region and activates the chip's pin action
- **THEN** a floating window containing the capture appears at the captured region's original screen position and size

#### Scenario: Pin from the Library
- **WHEN** the user invokes pin on a Library item
- **THEN** a floating window containing that item appears on the current display

### Requirement: Borderless always-on-top float
A pinned window SHALL be borderless (no title bar, no window chrome beyond an optional subtle edge treatment) and SHALL remain above all standard application windows, across Space switches and full-screen-adjacent use, until the user closes it. Pins MUST NOT appear in the Dock or the ⌘Tab application switcher, and creating a pin MUST NOT steal keyboard focus from the frontmost app.

#### Scenario: Pin stays on top
- **WHEN** the user activates another application's window after creating a pin
- **THEN** the pin remains visible above that application's windows

#### Scenario: Pin follows across Spaces
- **WHEN** the user switches to a different Space
- **THEN** the pin remains visible on the new Space

#### Scenario: Pin creation does not steal focus
- **WHEN** a pin is created while the user is typing in another app
- **THEN** keyboard focus remains in that app and no keystrokes are lost

### Requirement: Per-pin opacity control
Each pin SHALL have an independently adjustable opacity from 10% to 100%, adjustable via a hover control and via keyboard while the pin is hovered/active. The chosen opacity SHALL persist for the lifetime of that pin, and the last-used opacity SHALL be offered as the default for the next pin.

#### Scenario: Set a pin to 70% opacity
- **WHEN** the user adjusts a pin's opacity to 70%
- **THEN** the pin renders at 70% opacity while other pins keep their own opacity values

#### Scenario: Opacity floor
- **WHEN** the user reduces opacity to its minimum
- **THEN** the pin remains at least faintly visible (≥10%) and never becomes fully invisible while unlocked

### Requirement: Click-through lock
Each pin SHALL offer a click-through lock. While locked, the pin SHALL pass all mouse events (clicks, drags, scrolls) through to whatever is beneath it, allowing the user to work "through" the reference image. The app SHALL provide a discoverable unlock path that works while the pin is click-through (e.g. via the menu bar, a hotkey, or a modifier-hover affordance) — the user MUST never be stranded with an uncloseable, uninteractable pin.

#### Scenario: Locked pin passes clicks through
- **WHEN** a pin is click-through locked and the user clicks on its area
- **THEN** the click is received by the window beneath the pin
- **AND** the pin's position, size, and opacity are unchanged

#### Scenario: Unlocking a click-through pin
- **WHEN** the user invokes the documented unlock path on a locked pin
- **THEN** the pin becomes interactive again and responds to mouse events

### Requirement: Scroll-resize and size management
Scrolling over an unlocked pin SHALL resize it, anchored at the cursor, preserving aspect ratio. The app SHALL additionally provide: reset to 100% (actual pixel size), and a discrete zoom-step control. A pin MUST NOT be resizable below a minimum interactable size or beyond a maximum bounded by the largest attached display.

#### Scenario: Scroll to resize
- **WHEN** the user scrolls up over an unlocked pin
- **THEN** the pin grows with preserved aspect ratio
- **AND** scrolling down shrinks it

#### Scenario: Reset to actual size
- **WHEN** the user invokes reset-to-100% on a resized pin
- **THEN** the pin returns to a 1:1 mapping of image pixels to its original capture scale

### Requirement: Hide and show all pins via global hotkey
The app SHALL provide a global hotkey that toggles visibility of all pins at once without destroying them; hidden pins SHALL restore with identical position, size, opacity, and lock state. This supports instantly clearing pins for screen sharing and recalling them after.

#### Scenario: Hide all for screen share
- **WHEN** the user has three pins visible and presses the hide-all hotkey
- **THEN** all three pins become invisible immediately

#### Scenario: Show all restores exact state
- **WHEN** the user presses the hotkey again
- **THEN** all three pins reappear with their previous positions, sizes, opacities, and click-through states

### Requirement: Multiple simultaneous pins
The app SHALL support at least 10 simultaneous pins, each with independent state, including pins on different displays. A menu-bar list SHALL enumerate open pins with actions to focus, unlock, or close each, and a close-all-pins action SHALL exist.

#### Scenario: Independent multi-pin state
- **WHEN** the user creates pins on two displays and locks one of them
- **THEN** each pin retains its own opacity, size, and lock state, and the unlocked pin remains interactive

#### Scenario: Close all pins
- **WHEN** the user invokes close-all-pins
- **THEN** every pin window closes

### Requirement: Pin content actions and lifecycle
An unlocked pin SHALL offer: copy image to clipboard, save/export, open in editor, and close (via a hover control and Esc/⌘W while the pin is active). Closing a pin MUST NOT delete or modify the underlying capture in the Library. Pins are session-scoped: they SHALL NOT be restored after app relaunch.

#### Scenario: Copy from a pin
- **WHEN** the user invokes copy on a pin
- **THEN** the pinned image is placed on the clipboard and the pin remains open

#### Scenario: Closing a pin preserves the capture
- **WHEN** the user closes a pin whose image exists in the Library
- **THEN** the Library item is unaffected

## ADDED Requirements

### Requirement: Three-keystroke OCR capture loop
The app SHALL provide a dedicated global OCR hotkey that opens a region-selection overlay; on region selection (drag release), the app SHALL recognize all text inside the region and place the recognized text on the system clipboard as plain text without any further user action. The complete loop — hotkey, drag, paste — MUST require no interactions beyond those three steps (no confirmation dialog, no editor window, no save prompt).

#### Scenario: Hotkey to pasted text in three steps
- **WHEN** the user presses the OCR hotkey, drags a region containing text, and releases
- **THEN** the recognized text is on the system clipboard before any subsequent user input
- **AND** pressing ⌘V in any other app pastes that text
- **AND** no window requiring dismissal was opened during the loop

#### Scenario: OCR capture writes nothing to disk
- **WHEN** an OCR capture completes
- **THEN** no image or text file is created on disk as a user-facing artifact of the OCR operation

### Requirement: Toast preview of recognized text
After each OCR capture, the app SHALL display a transient, non-focus-stealing toast showing a preview of the recognized text and a character/line count, so the user can verify the result without pasting. The toast SHALL dismiss itself automatically and MUST NOT intercept keyboard input from the frontmost app.

#### Scenario: Toast appears and self-dismisses
- **WHEN** an OCR capture completes successfully
- **THEN** a toast appears showing at least the first lines of the recognized text
- **AND** the toast disappears automatically without user action
- **AND** keyboard focus remains in the app the user was using

#### Scenario: Toast reveals a bad recognition before paste
- **WHEN** the recognized text differs from what the user expected
- **THEN** the toast's preview content is the exact text that is on the clipboard, allowing the user to detect the mismatch before pasting

### Requirement: Automatic language detection
The app SHALL automatically detect the language(s) of text in the selected region and apply the appropriate recognition model without requiring the user to pre-select a language. Mixed-language regions SHALL be recognized per-run without manual switching. A manual language override setting SHALL exist but MUST default to automatic.

#### Scenario: Non-English text recognized without configuration
- **WHEN** the user OCR-captures a region containing only German text with language set to automatic
- **THEN** the German text is recognized and placed on the clipboard with correct diacritics
- **AND** the user performed no language selection step

#### Scenario: Mixed-language region
- **WHEN** a single region contains both English and Japanese text
- **THEN** both scripts appear in the clipboard output

### Requirement: Indentation and linebreak preservation modes
The app SHALL offer at least three text-layout modes for OCR output: (1) preserve layout — original linebreaks and leading indentation reproduced with spaces; (2) merge lines — soft-wrapped lines joined into paragraphs; (3) raw lines — one recognized line per output line, no indentation. The active mode SHALL be selectable in settings and switchable from the toast, and the chosen mode SHALL persist across captures.

#### Scenario: Code block keeps its indentation
- **WHEN** the user OCR-captures an indented code block in preserve-layout mode
- **THEN** the clipboard text reproduces each line's relative leading indentation and the original linebreaks
- **AND** pasting into a plain-text editor visually matches the captured block's structure

#### Scenario: Paragraph capture in merge-lines mode
- **WHEN** the user OCR-captures a soft-wrapped paragraph in merge-lines mode
- **THEN** the clipboard contains the paragraph as continuous text without mid-sentence linebreaks

#### Scenario: Mode change persists
- **WHEN** the user switches the layout mode and performs a new OCR capture after relaunching the app
- **THEN** the new capture uses the previously selected mode

### Requirement: Link detection in recognized text
When recognized text contains URLs or email addresses, the app SHALL detect them and surface them in the toast as actionable items (open in browser / copy individually). Detected links MUST also remain present verbatim in the plain-text clipboard output.

#### Scenario: URL in captured text is actionable
- **WHEN** the OCR region contains the text `https://example.com/docs`
- **THEN** the toast offers an action to open that URL
- **AND** the clipboard text still contains the URL verbatim

### Requirement: QR code detection
When the selected region contains one or more QR codes (or other machine-readable codes supported by the on-device framework), the app SHALL decode them and offer the payload via the toast: copy payload, and open when the payload is a URL. When a region contains both text and a QR code, the app SHALL place the recognized text on the clipboard and offer the QR payload as a separate toast action — it MUST NOT silently replace the text.

#### Scenario: QR code decoded from region
- **WHEN** the user OCR-captures a region containing only a QR code encoding a URL
- **THEN** the decoded URL is placed on the clipboard
- **AND** the toast offers an open-URL action

#### Scenario: Region with both text and QR code
- **WHEN** the region contains paragraph text and a QR code
- **THEN** the clipboard receives the recognized text
- **AND** the QR payload is offered as a distinct toast action without overwriting the clipboard unprompted

### Requirement: All recognition on-device
All OCR, language detection, link detection, and QR decoding SHALL execute on-device using OS-provided frameworks. The OCR feature MUST NOT initiate any network request, and captured pixels or recognized text MUST NOT leave the machine.

#### Scenario: OCR works offline
- **WHEN** the machine has no network connectivity and the user performs an OCR capture
- **THEN** recognition completes with full functionality
- **AND** no network request is attempted by the OCR feature

### Requirement: Honest empty-result behavior
When recognition finds no text (and no QR code) in the selected region, the app SHALL state this explicitly via the toast and MUST NOT modify the clipboard. Low-confidence results SHALL still be delivered (clipboard + toast) rather than silently dropped, so the user can judge them in the preview.

#### Scenario: No text found
- **WHEN** the user OCR-captures a region containing no recognizable text or codes
- **THEN** a toast states that no text was found
- **AND** the prior clipboard contents are unchanged

#### Scenario: Low-confidence text still delivered
- **WHEN** recognition produces text with low confidence (e.g. stylized fonts)
- **THEN** the text is placed on the clipboard and shown in the toast preview rather than being suppressed

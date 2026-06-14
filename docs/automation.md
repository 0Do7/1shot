# 1shot Automation API

1shot exposes its core actions to other tools two ways: **AppIntents** (Shortcuts
and Spotlight) and a **`oneshot://` URL scheme**. Both run on the same internal
dispatcher, so they obey the same rules: capture honors your trial/license state,
recognition runs entirely on-device, and 1shot never writes a file unless the
action's contract is to produce one.

This page documents the surface so third parties (and the official Raycast
extension / Alfred workflow, §13.6) can build on **public hooks only**.

- **Surface version:** `1` (`oneshot://version`). Breaking changes bump this.
- **Privacy posture:** no automation action transmits data over the network
  except through a destination *you* configured.

---

## AppIntents (Shortcuts & Spotlight)

These appear in the Shortcuts app under **1shot**, and the headline ones surface
as Spotlight actions automatically. They are always user-initiated, so they are
**not** gated by the URL-scheme toggle and never prompt for confirmation — but
they **are** subject to licensing and permission rules.

| Intent | Returns | Notes |
|---|---|---|
| Capture Area | — | Opens the area-selection overlay; result follows your chip/output config. |
| Capture Window | — | Window picker. |
| Capture Fullscreen | — | Current display. |
| Repeat Last Area | — | Re-captures the most recent area. |
| Start Scrolling Capture | — | Begins a scrolling session. |
| Extract Text from Region | `String` | Pick a region; returns recognized text. |
| Extract Text from Image | `String` | Pass an image file; returns recognized text (on-device). |
| Pin Image | — | Floats an image as a pin. *(Pin engine ships in §10.5; see Limitations.)* |
| Hide or Show All Pins | — | Toggles pin visibility. |
| Search Library | `[Library Item]` | Returns matching items to display/open in the launcher. |

**Capture intents return the captured image** so a following Shortcuts step (save
to folder, share, etc.) can consume it, and the workflow is **not** blocked by
1shot's own chip or editor.

---

## URL scheme (`oneshot://`) — OFF by default

> **The URL API is disabled until you turn it on.** While it is off, any incoming
> `oneshot://` call performs **no action**; 1shot shows a single notice telling
> you where to enable it and then stays quiet. Enable it in
> **1shot Settings › Automation**. The toggle explains that, once on, *any app on
> your Mac can trigger the enabled actions* — that is the whole point of the API,
> and the reason it ships off.

### Confirmation

Because any app can fire a URL, side-effecting actions (capture, region OCR, pin)
are **confirmable**. Per the per-action confirmation posture you can choose:

- **Always confirm** — 1shot asks you to approve before performing the action.
- **Silent** — the action runs without a prompt.

A single call can also force a prompt with `confirm=1`, even under silent mode.

### URL shape

```
oneshot://<action>[?param=value&…]
```

| Action (host) | Parameters | Effect | Success result |
|---|---|---|---|
| `capture-area` | — | Area-selection capture | `filePath` *(when produced)* |
| `capture-window` | — | Window capture | `filePath` |
| `capture-fullscreen` | — | Fullscreen capture | `filePath` |
| `capture-repeat` | — | Repeat last area | `filePath` |
| `capture-freeze` | — | Freeze-screen capture | `filePath` |
| `capture-scrolling` | — | Scrolling capture | `filePath` |
| `ocr-region` | — | OCR an interactively-picked region | `text` |
| `ocr-image` | `path` (required) | OCR an image file on disk | `text` |
| `pin` | `path` (optional) | Pin an image from `path`, or the pasteboard if omitted | — |
| `pins-toggle` | — | Hide/show all pins | — |
| `search` | `q` (or `query`) | Open the Library search seeded with the query | item list |
| `settings` | `pane` | Open Settings to a named pane | — |

`pane` is one of: `general`, `capture`, `shortcuts`, `library`, `destinations`,
`automation`, `about`. Omitting it opens `general`.

`path` accepts a tilde (`~/Desktop/shot.png`) and is expanded.

### Callbacks (x-callback-url)

Attach `x-success` / `x-error` URLs to receive results. 1shot opens your callback
with extra query parameters appended (your own callback params are preserved):

- **success:** `text=<recognized text>` for OCR, `filePath=<path>` for captures.
- **error:** `errorCode=<stable token>` and `errorMessage=<human text>`.

```
oneshot://ocr-image?path=~/Desktop/code.png&x-success=myapp://done&x-error=myapp://failed
```

On success 1shot opens `myapp://done?text=…`; on failure
`myapp://failed?errorCode=file-not-readable&errorMessage=…`.

### Errors

| `errorCode` | Meaning |
|---|---|
| `url-scheme-disabled` | The API is off. (Also shown as the in-app notice.) |
| `capture-requires-license` | The trial has ended; capture needs a license. Library search/export still work. |
| `screen-recording-permission-missing` | Grant Screen Recording, then retry. |
| `malformed-request` | Unknown action or invalid/missing parameter. **No action is taken and 1shot does not crash.** |
| `file-not-readable` | The `path` image could not be read. |
| `cancelled` | You declined the confirmation prompt. |

A malformed or unknown request always **fails safely**: no action, no crash, and —
if you supplied `x-error` — a descriptive error callback.

---

## Trial & license behavior

Automation enforces the same capture rules as interactive use:

- After the trial fully expires, **capture** actions (and interactive region OCR)
  fail with `capture-requires-license` — an explicit, honest error, never a silent
  no-op.
- **Library search, OCR on an existing image file, opening Settings, and toggling
  pins keep working forever.** Your data is never held hostage.

So a Shortcut that captures *and* searches will see the capture step fail after
expiry while the search step still returns results.

---

## Limitations (current build)

These surfaces are **defined and reachable** but their engines are owned by other
build lanes and not yet wired into the app:

- **Pin** (`pin`, `Pin Image` intent) — the pin engine lands in §10.5. The action
  currently fails honestly (`malformed-request`) rather than pretending to pin.
- **Interactive region OCR** (`ocr-region`, `Extract Text from Region`) — pending
  the in-app OCR capture flow (§8.3). OCR on a file (`ocr-image`) works today.
- **Open Search / Open Settings** — the Library window (§9) and Settings window
  (§13.3) are not wired yet; these requests are logged no-ops for now.
- **Library Search results** — structured results return empty until the app
  instantiates the Library store (§9).

The **parsing, gating (off-by-default, licensing, confirmation), and dispatch**
logic is complete and unit-tested; only the named app surfaces above are pending.

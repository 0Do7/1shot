# Deferred: Screen Recording (MP4 / GIF)

**Status:** locked v2 deferral (decided 2026-06-09). The research flags this as the locked
scope's **biggest risk** — it's CleanShot's #1 retention lever and Shottr's loudest wishlist
scream. The roadmap must treat it as the most-cited deferred feature, and marketing should show
it on the public roadmap.

## The spec bar (already cataloged from CleanShot, report §2.2)
- Region/window/fullscreen recording, MP4 + GIF export
- **System audio without driver installs** ("this feature alone is worth the price")
- Webcam PiP, pause/resume/**restart**, click/keystroke overlays
- Trim editor with live file-size readout
- v2 cloud tie-in bar: "link is copied before upload even finishes"

## Evidence
- VOC: "love shottr but why oh why can it not do video capture please I'm begging you"
- VOC: "screen recording to gif worth the price alone"; "No screen recording kills Shottr for me."
- Loom-replacement workflow is a recurring purchase justification ("saves me… not needing Loom").

## Architectural hooks kept in MVP
- Capture engine treats "recording" as a first-class capture *type* from day one (enum, not bolt-on).
- Post-capture chip/overlay surface is media-agnostic (image now; video later).
- Library schema stores media type + duration fields (nullable).

## Revisit trigger
v2 kickoff after MVP launch stabilizes; strongly signaled by churn-to-CleanShot feedback.

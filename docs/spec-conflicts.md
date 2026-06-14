# Spec conflicts & deviations log

Per build guide §0: conflicts found during implementation are logged here, never
silently resolved. Format: date · where · what · resolution.

## 2026-06-09 · design D2 vs task 1.3 · package count
Design D2's tree lists **8** packages + app; task 1.3 says "**9** packages + app
target". Resolved by adding `OneShotInstruments` (os_signpost + performance-budget
harness, task 1.5) as the 9th package — the harness needed a home importable by both
app and tests, and it must not live in portable OneShotCore (imports `os`).

## 2026-06-09 · build guide §3 vs SwiftFormat · test naming
Build guide says name tests `test_chip_neverStealsFocus`; SwiftFormat (law per §2)
strips the redundant `test` prefix on swift-testing `@Test` functions. Resolution:
scenario-based names keep the `<surface>_<scenario>` shape without the prefix
(`chip_neverStealsFocus`). Formatter wins — it's the mechanically-enforced rule.

## 2026-06-13 · spec:capture-engine area vs freeze · area selection captures a snapshot on open
The "Area selection" requirement implies a live overlay (final pixels from the
live screen at confirm), while "Freeze-screen" is the explicit frozen mode.
Task 3.2 implements area selection by grabbing a per-display snapshot at
invocation, dimming it as the overlay backdrop, and **cropping the confirmed
region out of that snapshot** rather than re-capturing live. Rationale: exact
WYSIWYG with the backdrop, no one-frame race where the dimming leaks into the
shot, and the snapshot is needed anyway for the pixel-accurate magnifier. Output
is still at the source display's native density, satisfying the requirement
verbatim. Consequence: the screen is visually frozen for the brief selection
lifetime; freeze-screen (3.4) becomes the same mechanism surfaced deliberately
(persistent + signposted), not a separate capture path. No spec text changed.

## 2026-06-09 · design D9 · "Core Image inpainting" does not exist
D9 assumed CI ships an inpainting facility. Spike S1 census on macOS 26.3: 247
CIFilters, zero inpaint/heal/reconstruct candidates. Resolution per S1 findings
(`docs/spikes/s1-inpainting.md`): MVP content-aware removal = CI **diffusion fill**
(beats blur-fill baseline 2–4×); custom patch-match kernel deferred post-MVP.
Spec requirement text unchanged (already mandates honest-failure messaging).

## 2026-06-14 · spec:output-destinations · S3/custom-endpoint destination (11.2) design decisions
No spec text changed; recording the design choices made implementing the upload
destination (package: OneShotDestinations).
- **Two-mode design, not one.** The spec describes an S3-style destination
  (endpoint/region/bucket/key/secret/prefix/URL-pattern). I implemented it as
  `EndpointDestination` with two modes behind the non-secret `mode` config field:
  `.s3` (local SigV4-signed `PUT object`) and `.customHTTP` (generic `PUT`/`POST`
  with configurable headers). This satisfies the spec's S3 requirement *and* the
  lane brief's "generic custom HTTP endpoint" ask without a second destination
  type. The "simplest correct path" (a presigned-URL `PUT` minted out-of-band) is
  just `.customHTTP` `PUT` with no stored credential — covered and tested.
- **SigV4 implemented (not only presigned).** The brief allowed presigned-URL PUT
  as the minimum; I also implemented full SigV4 so a user with raw access/secret
  keys can upload directly with zero external presigning service (spec: "zero
  hosting cost"). The security-critical canonical-request construction is asserted
  against AWS's published worked example (`GET iam ListUsers`, date 20150830):
  canonical request string + its SHA-256 (`f536975d…`) match the docs exactly;
  signing-key derivation and the end-to-end HMAC signature are verified against the
  values that canonical-request hash produces. The production S3 path additionally
  signs `x-amz-content-sha256` (S3 requires it), so its SignedHeaders list differs
  from the bare IAM vector — covered by a separate test.
- **Injectable seams (mirrors the licensing lane).** Network is behind
  `HTTPUploadClient` (`URLSessionUploadClient` in prod, `MockUploadClient` in
  tests — no real socket in any test, honoring spec "Network surface is limited to
  configured uploads"). Credentials are behind `EndpointCredentialStore`
  (`InMemoryCredentialStore` in tests; the real `SecItem` Keychain store lives in
  the app layer, exactly as `TrialOriginStore`'s Keychain impl does). The clock is
  injectable so SigV4 signatures are deterministic in tests.
- **Secrets-in-Keychain-only is by construction.** `EndpointCredentials` (the
  access/secret pair or a bearer token) is never part of `AppSettings`, only the
  injected store. The non-secret config (endpoint/region/bucket/prefix/URL-pattern)
  IS exported; the descriptor declares the credential field as `kind: .secret` so
  the settings exporter omits it and the UI routes it to the Keychain. Coordinates
  with Core 2.6's documented "destination secrets: Keychain only."
- **Honest failure surface.** HTTP 401/403 → `.unauthorized`, 404 → `.targetMissing`,
  other non-2xx → `.io` (folding the S3 `<Code>` element into the reason); transport
  errors classified into `.network` with DNS/TLS/connection causes. No public URL is
  rendered/copied unless the response is 2xx (spec: "no partial-success URL is
  copied"); the payload is never mutated, so the capture stays re-sendable.
- **App-layer remainder (deferred, NOT in this package):** the concrete
  `SecItem`-backed Keychain `EndpointCredentialStore`, the configuration/connection-
  test UI, and registry wiring belong to the §13 settings/platform lane. The domain
  logic here is fully headless-tested (32 tests, swiftlint --strict clean).

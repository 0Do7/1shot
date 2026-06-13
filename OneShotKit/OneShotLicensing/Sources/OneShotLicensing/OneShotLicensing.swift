/// OneShotLicensing — license activation, 3-seat management, Ed25519-signed
/// local receipts, 14-day offline grace, and the trial state machine (design
/// D10, spec E15). Mock-first: all behavior is exercised against the in-process
/// `MockLicenseServer`; the real Paddle REST client is task 14.3 (out of scope).
///
/// Trust posture (docs/00-decisions.md, design D10/D12): NO accounts/login, NO
/// subscription scaffolding, NO telemetry. The user's Library and exports work
/// forever regardless of license state — data is never held hostage. The only
/// permitted network surface (in 14.3) is the Paddle API.
public enum OneShotLicensingInfo {
    public static let packageName = "OneShotLicensing"
}

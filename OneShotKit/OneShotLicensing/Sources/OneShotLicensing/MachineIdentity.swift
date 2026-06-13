import Foundation

/// Identifies one Mac for seat counting. Carries a stable opaque `id` (the app
/// layer supplies it — e.g. a hash of the hardware UUID; the domain never
/// fingerprints) plus a human `name` so the seat-limit UI can list activations
/// by recognizable machine names (spec: "machine names/dates as available").
///
/// This is the ONLY device data licensing handles — there is no further
/// profiling (spec: "no invasive fingerprinting", "no device-profiling data").
public struct MachineIdentity: Codable, Hashable, Sendable {
    /// Stable, opaque per-Mac identifier. Comparison key for seat logic.
    public let id: String
    /// Display name for the activations list (e.g. "Cody's MacBook Pro").
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

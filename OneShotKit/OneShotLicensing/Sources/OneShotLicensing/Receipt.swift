import CryptoKit
import Foundation

/// The locally-cached proof of a successful activation (design D10). The payload
/// is signed with Ed25519 (`Curve25519.Signing`) on the server side; the app
/// verifies it OFFLINE on every launch against a bundled known public key. A
/// receipt that fails verification is treated as ABSENT — never a crash (spec:
/// "Tampered receipt ... behaves as unlicensed ... prompted to re-activate").
///
/// The signed bytes are the canonical (sorted-keys) JSON encoding of `payload`,
/// so signing and verifying agree byte-for-byte regardless of field order.
public struct LicenseReceipt: Codable, Equatable, Sendable {
    /// The signed claims.
    public struct Payload: Codable, Equatable, Sendable {
        /// The activated license key.
        public var licenseKey: String
        /// The Mac this receipt was issued for (seat binding).
        public var machine: MachineIdentity
        /// When the trial began on this install — mirrored from/into the trial
        /// store so a license receipt also carries the original trial origin
        /// (spec: "trial start recorded redundantly").
        public var trialStartedAt: Date
        /// Server timestamp of the most recent successful validation. Drives the
        /// 14-day offline-grace clock.
        public var lastValidatedAt: Date
        /// Seat occupancy at issue time, for the activations UI.
        public var seatsUsed: Int
        public var seatLimit: Int

        public init(
            licenseKey: String,
            machine: MachineIdentity,
            trialStartedAt: Date,
            lastValidatedAt: Date,
            seatsUsed: Int,
            seatLimit: Int
        ) {
            self.licenseKey = licenseKey
            self.machine = machine
            self.trialStartedAt = trialStartedAt
            self.lastValidatedAt = lastValidatedAt
            self.seatsUsed = seatsUsed
            self.seatLimit = seatLimit
        }
    }

    public var payload: Payload
    /// Ed25519 signature over `canonicalBytes(of: payload)`.
    public var signature: Data

    public init(payload: Payload, signature: Data) {
        self.payload = payload
        self.signature = signature
    }

    /// Canonical signing bytes: sorted-keys JSON so encode order can't change
    /// the signed message between signer and verifier.
    public static func canonicalBytes(of payload: Payload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(payload)
    }
}

public enum ReceiptError: Error, Equatable, Sendable {
    /// Signature did not verify against the trusted public key (tampered,
    /// wrong key, or corrupt). Caller treats the receipt as absent.
    case signatureInvalid
    case malformed
}

/// Server-side signer (lives with the mock license server; the real Paddle
/// integration in task 14.3 signs server-side with the matching private key).
public struct ReceiptSigner: Sendable {
    private let privateKey: Curve25519.Signing.PrivateKey

    public init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    public func sign(_ payload: LicenseReceipt.Payload) throws -> LicenseReceipt {
        let bytes = try LicenseReceipt.canonicalBytes(of: payload)
        let signature = try privateKey.signature(for: bytes)
        return LicenseReceipt(payload: payload, signature: signature)
    }
}

/// Offline verifier using the bundled known public key. No network.
public struct ReceiptVerifier: Sendable {
    private let publicKey: Curve25519.Signing.PublicKey

    public init(publicKey: Curve25519.Signing.PublicKey) {
        self.publicKey = publicKey
    }

    /// Construct from the raw 32-byte public-key representation that ships in
    /// the app bundle.
    public init(publicKeyRawRepresentation: Data) throws {
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRawRepresentation)
        } catch {
            throw ReceiptError.malformed
        }
    }

    /// Returns the verified payload, or throws `ReceiptError.signatureInvalid`.
    /// Verification failure is recoverable — callers fall back to unlicensed.
    @discardableResult
    public func verify(_ receipt: LicenseReceipt) throws -> LicenseReceipt.Payload {
        let bytes: Data
        do {
            bytes = try LicenseReceipt.canonicalBytes(of: receipt.payload)
        } catch {
            throw ReceiptError.malformed
        }
        guard publicKey.isValidSignature(receipt.signature, for: bytes) else {
            throw ReceiptError.signatureInvalid
        }
        return receipt.payload
    }

    /// Non-throwing convenience: `nil` means "treat as absent" (the spec's
    /// behavior for a tampered or unverifiable receipt).
    public func verifiedPayload(_ receipt: LicenseReceipt?) -> LicenseReceipt.Payload? {
        guard let receipt else { return nil }
        return try? verify(receipt)
    }
}

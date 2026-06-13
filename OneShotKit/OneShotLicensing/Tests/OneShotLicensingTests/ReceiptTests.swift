import CryptoKit
import Foundation
import Testing
@testable import OneShotLicensing

// 14.1 — Ed25519-signed local receipt: signing round-trips and any tamper fails
// verification (spec: "Paddle license activation" / "Tampered receipt").

struct ReceiptTests {
    private func samplePayload(now: Date = Fixtures.day0) -> LicenseReceipt.Payload {
        LicenseReceipt.Payload(
            licenseKey: Fixtures.validKey,
            machine: Fixtures.machineA,
            trialStartedAt: now,
            lastValidatedAt: now,
            seatsUsed: 1,
            seatLimit: 3
        )
    }

    @Test func signedReceiptVerifiesAgainstMatchingPublicKey() throws {
        let (signer, verifier) = Fixtures.keyPair()
        let receipt = try signer.sign(samplePayload())
        let verified = try verifier.verify(receipt)
        #expect(verified == receipt.payload)
    }

    /// Spec scenario: Tampered receipt — a modified receipt fails verification and
    /// is treated as absent (the verifier throws; manager turns that into unlicensed).
    @Test func tamperedReceipt() throws {
        let (signer, verifier) = Fixtures.keyPair()
        var receipt = try signer.sign(samplePayload())
        // Mutate a signed field; signature no longer matches the canonical bytes.
        receipt.payload.seatsUsed = 99
        #expect(throws: ReceiptError.signatureInvalid) {
            try verifier.verify(receipt)
        }
        // Non-throwing convenience treats it as absent.
        #expect(verifier.verifiedPayload(receipt) == nil)
    }

    @Test func tamperedSignatureBytesFailVerification() throws {
        let (signer, verifier) = Fixtures.keyPair()
        var receipt = try signer.sign(samplePayload())
        var sig = receipt.signature
        sig[0] ^= 0xFF // flip a byte of the signature
        receipt.signature = sig
        #expect(throws: ReceiptError.signatureInvalid) {
            try verifier.verify(receipt)
        }
    }

    /// A receipt signed by a DIFFERENT key must not verify against our public key
    /// (guards against forged receipts from an unrelated key pair).
    @Test func receiptFromWrongKeyFailsVerification() throws {
        let (signerA, _) = Fixtures.keyPair()
        let (_, verifierB) = Fixtures.keyPair()
        let receipt = try signerA.sign(samplePayload())
        #expect(throws: ReceiptError.signatureInvalid) {
            try verifierB.verify(receipt)
        }
    }

    /// Canonical bytes are stable regardless of field declaration order — proves
    /// signer/verifier agree on the signed message.
    @Test func canonicalBytesAreSortedKeysStable() throws {
        let bytes = try LicenseReceipt.canonicalBytes(of: samplePayload())
        let json = String(decoding: bytes, as: UTF8.self)
        // sorted-keys: "lastValidatedAt" precedes "licenseKey" precedes "machine".
        let iLast = try #require(json.range(of: "lastValidatedAt"))
        let iLicense = try #require(json.range(of: "licenseKey"))
        #expect(iLast.lowerBound < iLicense.lowerBound)
    }

    /// The verifier built from a raw 32-byte public key (as bundled in the app)
    /// verifies the same receipts.
    @Test func verifierFromRawPublicKeyRepresentationWorks() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let signer = ReceiptSigner(privateKey: priv)
        let verifier = try ReceiptVerifier(publicKeyRawRepresentation: priv.publicKey.rawRepresentation)
        let receipt = try signer.sign(samplePayload())
        #expect((try? verifier.verify(receipt)) != nil)
    }
}

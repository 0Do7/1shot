import Foundation
import Testing
@testable import OneShotDestinations

/// The SigV4 construction is the security-critical part of the S3 upload path, so
/// it is asserted against AWS's published worked example ("Examples of the
/// complete Signature Version 4 signing process" — the `GET iam ListUsers`
/// vector) rather than only against itself. If any step (canonical request,
/// string-to-sign, signing-key derivation) drifts, the documented signature
/// stops matching.
///
/// Vector:
///   Access key id : AKIDEXAMPLE
///   Secret key    : wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
///   Region/service: us-east-1 / iam
///   Date          : 20150830T123600Z
///   Request       : GET https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08
///   Signed headers: content-type;host;x-amz-date
struct SigV4SignerTests {
    private static let secret = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    private static let amzDate = "20150830T123600Z"
    private static let dateStamp = "20150830"
    private static let url = URL(string: "https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08")!
    private static let contentType = "application/x-www-form-urlencoded; charset=utf-8"

    private static var headersToSign: [String: String] {
        [
            "content-type": contentType,
            "host": "iam.amazonaws.com",
            "x-amz-date": amzDate,
        ]
    }

    /// Empty-body payload hash — the documented value.
    private static let emptyPayloadHash =
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    @Test func sha256OfEmptyBodyMatchesDocumentedHash() {
        #expect(SigV4Signer.hexSHA256(Data()) == Self.emptyPayloadHash)
    }

    @Test func canonicalRequestMatchesAWSWorkedExample() {
        let canonical = SigV4Signer.canonicalRequest(
            method: "GET",
            url: Self.url,
            headersToSign: Self.headersToSign,
            payloadHash: Self.emptyPayloadHash
        )
        let expected = """
        GET
        /
        Action=ListUsers&Version=2010-05-08
        content-type:application/x-www-form-urlencoded; charset=utf-8
        host:iam.amazonaws.com
        x-amz-date:20150830T123600Z

        content-type;host;x-amz-date
        e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        """
        #expect(canonical == expected)
    }

    @Test func canonicalRequestHashMatchesDocumentedValue() {
        let canonical = SigV4Signer.canonicalRequest(
            method: "GET",
            url: Self.url,
            headersToSign: Self.headersToSign,
            payloadHash: Self.emptyPayloadHash
        )
        // AWS docs: hashed canonical request for this vector.
        #expect(
            SigV4Signer.hexSHA256(Data(canonical.utf8))
                == "f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59"
        )
    }

    @Test func signingKeyDerivationMatchesDocumentedKey() {
        let key = SigV4Signer.signingKey(
            secret: Self.secret,
            dateStamp: Self.dateStamp,
            region: "us-east-1",
            service: "iam"
        )
        let hex = key.withUnsafeBytes { SigV4Signer.hex(Data($0)) }
        // Derived signing key for 20150830 / us-east-1 / iam (HMAC-SHA256 chain
        // kSecret→kDate→kRegion→kService→kSigning).
        #expect(hex == "2c94c0cf5378ada6887f09bb697df8fc0affdb34ba1cdd5bda32b664bd55b73c")
    }

    /// End-to-end signature over the AWS worked-example canonical request. This
    /// drives `authorizationHeader` with the vector's exact signed-header set
    /// (content-type;host;x-amz-date), so it exercises the full
    /// canonical-request → string-to-sign → signing-key → HMAC pipeline against
    /// the documented canonical-request hash.
    @Test func authorizationSignatureMatchesWorkedExampleCanonicalRequest() {
        let signer = SigV4Signer(
            accessKeyID: "AKIDEXAMPLE",
            secretAccessKey: Self.secret,
            region: "us-east-1",
            service: "iam"
        )
        let auth = signer.authorizationHeader(
            method: "GET",
            url: Self.url,
            headersToSign: Self.headersToSign,
            payloadHash: Self.emptyPayloadHash,
            amzDate: Self.amzDate
        )
        #expect(auth.contains("Signature=33f5dad2191de0cb4b7ab912f876876c2c4f72e2991a458f9499233c7b992438"))
        #expect(auth.contains("Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request"))
        #expect(auth.contains("SignedHeaders=content-type;host;x-amz-date"))
    }

    /// The production S3 path (`signedHeaders`) always signs `x-amz-content-sha256`
    /// — S3 rejects a request that omits it from the signed set — and emits the
    /// content hash + date headers we then send verbatim.
    @Test func signedHeadersForS3IncludesContentHashInSignedSet() throws {
        let signer = SigV4Signer(
            accessKeyID: "AKIDEXAMPLE",
            secretAccessKey: Self.secret,
            region: "us-east-1"
        )
        let request = try HTTPUploadRequest(
            method: .put,
            url: #require(URL(string: "https://bucket.s3.amazonaws.com/key.png")),
            headers: ["Content-Type": "image/png"],
            body: Data([0x89, 0x50])
        )
        let date = try #require(SigV4Signer.amzDateFormatter.date(from: Self.amzDate))
        let headers = signer.signedHeaders(for: request, date: date, host: "bucket.s3.amazonaws.com")

        let auth = try #require(headers["Authorization"])
        #expect(auth.contains("SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date"))
        #expect(auth.contains("/us-east-1/s3/aws4_request"))
        #expect(headers["x-amz-content-sha256"] == SigV4Signer.hexSHA256(Data([0x89, 0x50])))
        #expect(headers["x-amz-date"] == Self.amzDate)
    }

    @Test func uriEncodingFollowsAWSUnreservedRules() {
        // Unreserved set is preserved; everything else percent-encoded uppercase.
        #expect(SigV4Signer.uriEncode("abcXYZ-_.~", encodeSlash: true) == "abcXYZ-_.~")
        #expect(SigV4Signer.uriEncode("a b", encodeSlash: true) == "a%20b")
        #expect(SigV4Signer.uriEncode("a/b", encodeSlash: true) == "a%2Fb")
        #expect(SigV4Signer.uriEncode("a/b", encodeSlash: false) == "a/b")
    }

    @Test func canonicalPathEncodesSegmentsButKeepsSeparators() throws {
        let url = try #require(URL(string: "https://host/my folder/file name.png"))
        #expect(SigV4Signer.canonicalURIPath(url) == "/my%20folder/file%20name.png")
    }
}

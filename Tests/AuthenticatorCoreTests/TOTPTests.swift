import XCTest
@testable import AuthenticatorCore

final class TOTPTests: XCTestCase {
    private let sha1Key = Data("12345678901234567890".utf8)
    private let sha256Key = Data("12345678901234567890123456789012".utf8)
    private let sha512Key = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    private func code(_ key: Data, _ algo: TOTPAlgorithm, _ t: TimeInterval) -> String {
        TOTP.code(secret: key, digits: 8, period: 30, algorithm: algo, at: Date(timeIntervalSince1970: t))
    }

    // RFC 6238 Appendix B test vectors.
    func testRFC6238Sha1() {
        XCTAssertEqual(code(sha1Key, .sha1, 59), "94287082")
        XCTAssertEqual(code(sha1Key, .sha1, 1111111109), "07081804")
        XCTAssertEqual(code(sha1Key, .sha1, 1111111111), "14050471")
        XCTAssertEqual(code(sha1Key, .sha1, 1234567890), "89005924")
        XCTAssertEqual(code(sha1Key, .sha1, 2000000000), "69279037")
        XCTAssertEqual(code(sha1Key, .sha1, 20000000000), "65353130")
    }

    func testRFC6238Sha256And512() {
        XCTAssertEqual(code(sha256Key, .sha256, 59), "46119246")
        XCTAssertEqual(code(sha512Key, .sha512, 59), "90693936")
    }

    func testBase32() {
        XCTAssertEqual(Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"), sha1Key)
        XCTAssertEqual(Base32.decode("gezd gnbv-GY3TQOJQGEZDGNBVGY3TQOJQ=="), sha1Key)
        XCTAssertNil(Base32.decode("not base32!"))
        XCTAssertNil(Base32.decode(""))
    }

    func testParseURI() throws {
        let uri = "otpauth://totp/Example%20Co:user@example.com?secret=JBSWY3DPEHPK3PXP&digits=8&period=60&algorithm=SHA256"
        let account = try OtpauthURI.parse(uri)
        XCTAssertEqual(account.issuer, "Example Co")
        XCTAssertEqual(account.name, "user@example.com")
        XCTAssertEqual(account.digits, 8)
        XCTAssertEqual(account.period, 60)
        XCTAssertEqual(account.algorithm, .sha256)
    }

    func testParseURIIssuerParamWins() throws {
        let account = try OtpauthURI.parse("otpauth://totp/Old:me?secret=JBSWY3DPEHPK3PXP&issuer=New")
        XCTAssertEqual(account.issuer, "New")
        XCTAssertEqual(account.name, "me")
    }

    func testRejectsBadInput() {
        XCTAssertThrowsError(try OtpauthURI.parse("https://example.com"))
        XCTAssertThrowsError(try OtpauthURI.parse("otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP"))
        XCTAssertThrowsError(try OtpauthURI.parse("otpauth://totp/x"))
        XCTAssertThrowsError(try OtpauthURI.parse("otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&period=0"))
        XCTAssertThrowsError(try OtpauthURI.parse("otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&digits=20"))
    }
}

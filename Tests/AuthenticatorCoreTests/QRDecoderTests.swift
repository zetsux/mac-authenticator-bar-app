import CoreImage
import CoreImage.CIFilterBuiltins
import XCTest
@testable import AuthenticatorCore

final class QRDecoderTests: XCTestCase {
    func testRoundTripThroughOtpauthParser() throws {
        let text = "otpauth://totp/Example:me@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        let scaled = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let cg = try XCTUnwrap(CIContext().createCGImage(scaled, from: scaled.extent))

        let messages = QRDecoder.messages(in: cg)
        XCTAssertEqual(messages, [text])
        XCTAssertEqual(try OtpauthURI.parse(messages[0]).issuer, "Example")
    }

    func testBlankImageHasNoQRCode() throws {
        let blank = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let cg = try XCTUnwrap(CIContext().createCGImage(blank, from: blank.extent))
        XCTAssertTrue(QRDecoder.messages(in: cg).isEmpty)
    }
}

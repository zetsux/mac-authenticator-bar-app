import CryptoKit
import Foundation

public enum TOTPAlgorithm: String, Codable, CaseIterable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

public enum TOTP {
    /// RFC 6238 time-based one-time password.
    public static func code(
        secret: Data,
        digits: Int = 6,
        period: Int = 30,
        algorithm: TOTPAlgorithm = .sha1,
        at date: Date = Date()
    ) -> String {
        let counter = UInt64(max(0, date.timeIntervalSince1970)) / UInt64(max(1, period))
        var big = counter.bigEndian
        let message = Data(bytes: &big, count: MemoryLayout<UInt64>.size)
        let key = SymmetricKey(data: secret)

        let mac: [UInt8]
        switch algorithm {
        case .sha1: mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: mac = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: mac = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }

        let offset = Int(mac[mac.count - 1] & 0x0f)
        let binary = (UInt32(mac[offset] & 0x7f) << 24)
            | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])

        var modulus: UInt32 = 1
        for _ in 0..<digits { modulus *= 10 }
        let raw = String(binary % modulus)
        return String(repeating: "0", count: max(0, digits - raw.count)) + raw
    }

    public static func secondsRemaining(period: Int, at date: Date = Date()) -> Int {
        let p = max(1, period)
        return p - Int(date.timeIntervalSince1970) % p
    }
}

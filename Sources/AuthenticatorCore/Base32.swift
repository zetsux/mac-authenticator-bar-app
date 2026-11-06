import Foundation

public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    /// RFC 4648 decode. Ignores padding, spaces and dashes. Returns nil on invalid characters or empty input.
    public static func decode(_ input: String) -> Data? {
        var bits: UInt32 = 0
        var count = 0
        var out = Data()
        for ch in input.uppercased() {
            if ch == "=" || ch == " " || ch == "-" { continue }
            guard let value = alphabet.firstIndex(of: ch) else { return nil }
            bits = (bits << 5) | UInt32(value)
            count += 5
            if count >= 8 {
                count -= 8
                out.append(UInt8((bits >> UInt32(count)) & 0xff))
                bits &= (1 << UInt32(count)) - 1
            }
        }
        return out.isEmpty ? nil : out
    }
}

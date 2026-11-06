import Foundation

public enum AccountError: LocalizedError {
    case invalidURI
    case missingSecret
    case invalidSecret
    case invalidDigits
    case invalidPeriod
    case unknownAlgorithm(String)
    case duplicate
    case noQRCode

    public var errorDescription: String? {
        switch self {
        case .invalidURI: return "Not a valid otpauth://totp URI."
        case .missingSecret: return "A secret is required."
        case .invalidSecret: return "That does not look like a valid Base32 secret."
        case .invalidDigits: return "Digits must be between 6 and 8."
        case .invalidPeriod: return "Period must be between 1 and 300 seconds."
        case .unknownAlgorithm(let name): return "Unsupported algorithm: \(name)."
        case .duplicate: return "That account is already added."
        case .noQRCode: return "No QR code found in that image."
        }
    }
}

public struct Account: Codable, Identifiable, Equatable {
    public var id: UUID
    public var issuer: String
    public var name: String
    public var secret: String
    public var digits: Int
    public var period: Int
    public var algorithm: TOTPAlgorithm

    public init(
        id: UUID = UUID(),
        issuer: String,
        name: String,
        secret: String,
        digits: Int = 6,
        period: Int = 30,
        algorithm: TOTPAlgorithm = .sha1
    ) {
        self.id = id
        self.issuer = issuer
        self.name = name
        self.secret = secret
        self.digits = digits
        self.period = period
        self.algorithm = algorithm
    }

    public var secretData: Data? { Base32.decode(secret) }

    public func validate() throws {
        if secret.trimmingCharacters(in: .whitespaces).isEmpty { throw AccountError.missingSecret }
        if secretData == nil { throw AccountError.invalidSecret }
        if !(6...8).contains(digits) { throw AccountError.invalidDigits }
        if !(1...300).contains(period) { throw AccountError.invalidPeriod }
    }

    public func currentCode(at date: Date = Date()) -> String {
        guard let data = secretData else { return String(repeating: "-", count: digits) }
        return TOTP.code(secret: data, digits: digits, period: period, algorithm: algorithm, at: date)
    }
}

public enum OtpauthURI {
    public static func parse(_ raw: String) throws -> Account {
        guard
            let components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            components.scheme?.lowercased() == "otpauth",
            components.host?.lowercased() == "totp"
        else { throw AccountError.invalidURI }

        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value { params[item.name.lowercased()] = value }
        }
        guard let secret = params["secret"], !secret.isEmpty else { throw AccountError.missingSecret }

        var label = components.path
        if label.hasPrefix("/") { label.removeFirst() }
        var issuerFromLabel = ""
        var name = label
        if let colon = label.firstIndex(of: ":") {
            issuerFromLabel = String(label[..<colon]).trimmingCharacters(in: .whitespaces)
            name = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }

        var algorithm = TOTPAlgorithm.sha1
        if let algo = params["algorithm"] {
            guard let parsed = TOTPAlgorithm(rawValue: algo.uppercased()) else {
                throw AccountError.unknownAlgorithm(algo)
            }
            algorithm = parsed
        }

        let account = Account(
            issuer: params["issuer"] ?? (issuerFromLabel.isEmpty ? "Account" : issuerFromLabel),
            name: name,
            secret: secret,
            digits: Int(params["digits"] ?? "") ?? 6,
            period: Int(params["period"] ?? "") ?? 30,
            algorithm: algorithm
        )
        try account.validate()
        return account
    }
}

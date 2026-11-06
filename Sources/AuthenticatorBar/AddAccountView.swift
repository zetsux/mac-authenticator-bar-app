import AppKit
import AuthenticatorCore
import SwiftUI

struct AddAccountView: View {
    @ObservedObject var store: AccountStore
    let done: () -> Void

    private enum Mode: String, CaseIterable { case qr = "Scan QR", link = "Link", manual = "Manual" }

    @State private var mode: Mode = .qr
    @State private var uri = ""
    @State private var issuer = ""
    @State private var name = ""
    @State private var secret = ""
    @State private var digits = "6"
    @State private var period = "30"
    @State private var error: String?
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch mode {
            case .qr: qrBody
            case .link: linkBody
            case .manual: manualBody
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if mode != .qr {
                HStack {
                    Spacer()
                    Button("Cancel", action: done)
                    Button("Add", action: submit).keyboardShortcut(.defaultAction)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(14)
    }

    private var qrBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1. Open the 2FA setup page that shows a QR code.\n2. Screenshot it: ⌘ ⌃ ⇧ 4, then drag over the QR.\n3. Click the button below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: scanClipboard) {
                Label("Scan QR from clipboard", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Text("Or drop a QR image file here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
                )
                .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)

            HStack {
                Spacer()
                Button("Cancel", action: done)
            }
        }
    }

    private var linkBody: some View {
        TextField("otpauth://totp/Issuer:account?secret=...", text: $uri, axis: .vertical)
            .lineLimit(3...5)
            .font(.system(size: 12, design: .monospaced))
    }

    private var manualBody: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Issuer (e.g. Example)", text: $issuer)
                TextField("Account (e.g. user@example.com)", text: $name)
            }
            TextField("Secret (Base32)", text: $secret)
                .font(.system(size: 12, design: .monospaced))
            HStack {
                TextField("Digits", text: $digits)
                TextField("Period (s)", text: $period)
            }
        }
    }

    // MARK: Actions

    private func scanClipboard() {
        guard
            let image = NSImage(pasteboard: .general),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            error = "No screenshot on the clipboard. Press ⌘ ⌃ ⇧ 4 and drag over the QR first."
            return
        }
        importQR(from: cgImage)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            let cgImage = url
                .flatMap { NSImage(contentsOf: $0) }
                .flatMap { $0.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            DispatchQueue.main.async {
                if let cgImage { importQR(from: cgImage) } else { error = "That file is not an image." }
            }
        }
        return true
    }

    private func importQR(from image: CGImage) {
        do {
            let messages = QRDecoder.messages(in: image)
            guard !messages.isEmpty else { throw AccountError.noQRCode }
            for message in messages { try store.add(OtpauthURI.parse(message)) }
            done()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submit() {
        do {
            let account: Account
            switch mode {
            case .qr:
                return
            case .link:
                account = try OtpauthURI.parse(uri)
            case .manual:
                let trimmedIssuer = issuer.trimmingCharacters(in: .whitespaces)
                account = Account(
                    issuer: trimmedIssuer.isEmpty ? "Account" : trimmedIssuer,
                    name: name.trimmingCharacters(in: .whitespaces),
                    secret: secret.trimmingCharacters(in: .whitespaces),
                    digits: Int(digits) ?? 6,
                    period: Int(period) ?? 30
                )
            }
            try store.add(account)
            done()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

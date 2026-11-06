import AuthenticatorCore
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: AccountStore
    let close: () -> Void

    @State private var adding = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = store.storageError {
                storageErrorView(error)
            } else if adding {
                AddAccountView(store: store, done: { adding = false })
            } else {
                AccountListView(store: store, close: close)
            }
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Authenticator").font(.headline)
            Spacer()
            if store.storageError == nil {
                Button {
                    adding.toggle()
                } label: {
                    Image(systemName: adding ? "xmark" : "plus")
                }
                .buttonStyle(.borderless)
                .help(adding ? "Cancel" : "Add account")
            }
            Menu {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                Text("Hotkey: Control + Option + O")
                Divider()
                Button("Quit Authenticator") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func storageErrorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message).font(.callout).foregroundStyle(.red).multilineTextAlignment(.center)
            Button("Retry") { store.load() }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Launch at login change failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct AccountListView: View {
    @ObservedObject var store: AccountStore
    let close: () -> Void

    @State private var copiedID: UUID?

    private let rowHeight: CGFloat = 62

    var body: some View {
        if store.accounts.isEmpty {
            Text("No accounts yet.\nTap + to add one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.accounts) { account in
                            AccountRow(
                                account: account,
                                now: timeline.date,
                                copied: copiedID == account.id,
                                onCopy: { copy(account, at: timeline.date) },
                                onDelete: { confirmRemove(account) }
                            )
                            .frame(height: rowHeight)
                            Divider()
                        }
                    }
                }
                .frame(height: min(CGFloat(store.accounts.count) * (rowHeight + 1), 330))
            }
        }
    }

    /// Cancel is the first (default) button so pressing Return never deletes anything.
    private func confirmRemove(_ account: Account) {
        let label = account.name.isEmpty ? account.issuer : "\(account.issuer) (\(account.name))"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove \(label)?"
        alert.informativeText = "This deletes the secret from this Mac. If it is your only copy, you will have to set up two-factor authentication again with the service, and you could be locked out without a backup code."
        alert.addButton(withTitle: "Cancel")
        let remove = alert.addButton(withTitle: "Remove")
        remove.hasDestructiveAction = true

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            store.remove(id: account.id)
        }
    }

    private func copy(_ account: Account, at date: Date) {
        Clipboard.copySecret(account.currentCode(at: date))
        copiedID = account.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { close() }
    }
}

struct AccountRow: View {
    let account: Account
    let now: Date
    let copied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        let remaining = TOTP.secondsRemaining(period: account.period, at: now)

        HStack(spacing: 12) {
            CountdownRing(remaining: remaining, period: account.period)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.issuer).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                if !account.name.isEmpty {
                    Text(account.name).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
                }
                Text(copied ? "Copied" : formatted(account.currentCode(at: now)))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(copied ? Color.green : Color.primary)
            }

            Spacer(minLength: 0)

            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(copied ? Color.green : Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.borderless)
            .help("Copy code")
        }
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .background(hovering ? Color.primary.opacity(0.06) : Color.clear)
        .onHover { hovering = $0 }
        .onTapGesture(perform: onCopy)
        .contextMenu {
            Button("Copy code", action: onCopy)
            Divider()
            Button("Remove account…", role: .destructive, action: onDelete)
        }
    }

    private func formatted(_ code: String) -> String {
        guard code.count > 4 else { return code }
        let mid = code.index(code.startIndex, offsetBy: (code.count + 1) / 2)
        return code[..<mid] + " " + code[mid...]
    }
}

struct CountdownRing: View {
    let remaining: Int
    let period: Int

    private var color: Color {
        remaining <= 5 ? .red : (remaining <= 10 ? .orange : .green)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(period))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            Text("\(remaining)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(width: 30, height: 30)
    }
}

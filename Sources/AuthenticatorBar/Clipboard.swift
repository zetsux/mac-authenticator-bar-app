import AppKit

enum Clipboard {
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Copies a code, marks it concealed so clipboard managers (Maccy included) skip it,
    /// and clears it after 30 seconds if nothing else was copied in the meantime.
    static func copySecret(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, concealed], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: concealed)

        let count = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if pasteboard.changeCount == count { pasteboard.clearContents() }
        }
    }
}

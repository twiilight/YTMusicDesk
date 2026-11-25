import AppKit

/// Presents native macOS `NSAlert` sheets for JavaScript `alert`, `confirm`, and `prompt` panels.
@MainActor
enum WebDialogPresenter {
    static func presentAlert(
        title: String,
        message: String,
        window: NSWindow?,
        completion: @escaping @MainActor () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        if let window {
            alert.beginSheetModal(for: window) { _ in completion() }
        } else {
            alert.runModal()
            completion()
        }
    }

    static func presentConfirm(
        title: String,
        message: String,
        window: NSWindow?,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if let window {
            alert.beginSheetModal(for: window) { response in
                completion(response == .alertFirstButtonReturn)
            }
        } else {
            completion(alert.runModal() == .alertFirstButtonReturn)
        }
    }

    static func presentPrompt(
        title: String,
        prompt: String,
        defaultText: String?,
        window: NSWindow?,
        completion: @escaping @MainActor (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField

        if let window {
            alert.beginSheetModal(for: window) { response in
                completion(response == .alertFirstButtonReturn ? textField.stringValue : nil)
            }
        } else {
            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn ? textField.stringValue : nil)
        }
    }
}

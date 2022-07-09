import Foundation
import Cocoa
import Sauce

class Clipboard {
    private var accessibilityAllowed: Bool { AXIsProcessTrustedWithOptions(nil) }
    private var accessibilityAlert: NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("“MacCopier“想要使用“辅助功能”控制此计算机。", comment: "")
        alert.informativeText = NSLocalizedString("在“系统偏好设置”中的“安全性和隐私”设置中授予此应用程序权限, 设置完成后请重新点击“自动粘贴“", comment: "")
        alert.addButton(withTitle: NSLocalizedString("拒绝", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("打开系统偏好设置", comment: ""))
        alert.icon = NSImage(named: "NSSecurity")
        return alert
    }
    private let accessibilityURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
    
    private func showAccessibilityWindow() {
        if accessibilityAlert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn {
            if let url = accessibilityURL {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
    }
    
    // https://github.com/Clipy/Clipy/blob/40445fd4f453edf5dd39cf18b9e4b5ffbf48deaa/Clipy/Sources/Services/PasteService.swift#L142
    func paste() {
        if self.checkAutoPastePermission() == false {
            return
        }
        
        DispatchQueue.main.async {
            let vCode = Sauce.shared.keyCode(for: .v)
            let source = CGEventSource(stateID: .combinedSessionState)
            // Disable local keyboard events while pasting
            source?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents],
                                                               state: .eventSuppressionStateSuppressionInterval)
            
            let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: true)
            let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: false)
            keyVDown?.flags = .maskCommand
            keyVUp?.flags = .maskCommand
            keyVDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyVUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
    
    func checkAutoPastePermission() -> Bool {
        guard accessibilityAllowed else {
            // Show accessibility window async to allow menu to close.
            DispatchQueue.main.async(execute: showAccessibilityWindow)
            return false
        }
        return true
    }
}

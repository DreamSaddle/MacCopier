import Cocoa

class About {
  private let familyCredits = NSAttributedString(
    string: "Made with by DreamSaddle",
    attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor]
  )

  private var links: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "Website│GitHub│Contact",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "https://taohan.xyz/article/maccopier", range: NSRange(location: 0, length: 7))
    string.addAttribute(.link, value: "https://github.com/DreamSaddle/MacCopier", range: NSRange(location: 8, length: 6))
    string.addAttribute(.link, value: "mailto:1289747698@qq.com", range: NSRange(location: 15, length: 7))
    return string
  }

  private var credits: NSMutableAttributedString {
    let credits = NSMutableAttributedString(string: "",
                                            attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    credits.append(links)
    credits.append(NSAttributedString(string: "\n\n"))
    credits.append(familyCredits)
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }

  @objc
  func openAbout(_ sender: Any) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}

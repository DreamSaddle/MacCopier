import Cocoa
import Settings

class RegexSettingViewController: NSViewController, SettingsPane {
    public let paneIdentifier = Settings.PaneIdentifier(rawValue: "preferences_regex")
    public let paneTitle = "匹配规则"
    public let toolbarItemIcon = NSImage(named: NSImage.touchBarNewMessageTemplateName)!
    
    override var nibName: NSNib.Name? { "RegexSettingViewController" }

    @IBOutlet weak var msgMatchKeywordsTextField: NSTextField!
    @IBOutlet weak var msgCodeMatchPatternTextField: NSTextField!
    
    override func viewDidLoad() {
      super.viewDidLoad()
      self.preferredContentSize = NSSize.init(width: 400, height: 180)
    }

    override func viewWillAppear() {
      super.viewWillAppear()
      populateMsgMatchKeywordsTextField()
      populateMsgCodeMatchPatternTextField()
    }
    
    @IBAction func msgMatchKeywordsTextFieldChanged(_ sender: NSTextField) {
//        print("匹配关键词: ", sender.stringValue)
        UserDefaults.standard.msgMatchKeywords = sender.stringValue.isEmpty ? nil : sender.stringValue
    }
    @IBAction func msgCodeMatchPatternTextFieldChanged(_ sender: NSTextField) {
//        print("验证码正则表达式: ", sender.stringValue)
        UserDefaults.standard.msgCodeMatchPattern = sender.stringValue.isEmpty ? nil : sender.stringValue
    }

    
    private func populateMsgMatchKeywordsTextField() {
        msgMatchKeywordsTextField.stringValue = UserDefaults.standard.msgMatchKeywords ?? Constants.DEFAULT_MSG_MATCH_KEYWORDS
    }
    
    private func populateMsgCodeMatchPatternTextField() {
        msgCodeMatchPatternTextField.stringValue = UserDefaults.standard.msgCodeMatchPattern ?? Constants.DEFAULT_MSG_CODE_MATCH_PATTERN
    }
}

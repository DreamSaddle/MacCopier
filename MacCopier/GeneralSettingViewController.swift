import Cocoa
import Settings
import LaunchAtLogin


class GeneralSettingViewController: NSViewController, SettingsPane {
    public let paneIdentifier = Settings.PaneIdentifier(rawValue: "preferences_general")
    public let paneTitle = "Setting"
    public let toolbarItemIcon = NSImage(named: NSImage.infoName)!
    
    override var nibName: NSNib.Name? { "GeneralSettingViewController" }
    
    
    @IBOutlet weak var launchAtLoginButton: NSButton!
    @IBOutlet weak var autoPasteButton: NSButton!
    
    override func viewDidLoad() {
      super.viewDidLoad()
      self.preferredContentSize = NSSize.init(width: 400, height: 300)
    }

    override func viewWillAppear() {
      super.viewWillAppear()
      populateLaunchAtLogin()
      populateAutoPaste()
    }
    
    
    
    @IBAction func launchAtLoginChanged(_ sender: NSButton) {
        LaunchAtLogin.isEnabled = (sender.state == .on)
    }
    
    @IBAction func autoPasteChanged(_ sender: NSButton) {
        if sender.state == .on && ClipboardController.clipboard.checkAutoPastePermission() == false {
            autoPasteButton.state = .off
            UserDefaults.standard.autoPaste = false
            return
        }
        autoPasteButton.state = sender.state
        UserDefaults.standard.autoPaste = sender.state == .on
    }
    
    private func populateLaunchAtLogin() {
      launchAtLoginButton.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    private func populateAutoPaste() {
        autoPasteButton.state = UserDefaults.standard.autoPaste ? .on : .off
    }
    

}

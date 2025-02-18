import Cocoa
import SwiftUI
import SQLite3
import Settings

class Message {
    var messageDate: Int32
    var text: String
    init(messageDate: Int32, text: String) {
        self.messageDate = messageDate
        self.text = text
    }
}

struct Constants {
    static let DEFAULT_MSG_MATCH_KEYWORDS = ""
    static let DEFAULT_MSG_CODE_MATCH_PATTERN = "\\b([0-9]{4,8})\\b"
}

// 扩展 UserDefaults 存储用户数据
extension UserDefaults {
    public struct Keys {
        static let autoPaste = "autoPaste"
        static let hiddenStatusBar = "hiddenStatusBar"
        static let msgMatchKeywords = "msgMatchKeywords"
        static let msgCodeMatchPattern = "msgCodeMatchPattern"
        static let pythonSciprt = "pythonSciprt"
    }
    
    struct ConfigValues {
        static let autoPaste = false
        static let hiddenStatusBar = false
        static let msgMatchKeywords = Constants.DEFAULT_MSG_MATCH_KEYWORDS
        static let msgCodeMatchPattern = Constants.DEFAULT_MSG_CODE_MATCH_PATTERN
    }
    
    @objc dynamic public var autoPaste: Bool {
        get { bool(forKey: Keys.autoPaste) }
        set { set(newValue, forKey: Keys.autoPaste) }
    }
    @objc dynamic public var hiddenStatusBar: Bool {
        get { bool(forKey: Keys.hiddenStatusBar) }
        set { set(newValue, forKey: Keys.hiddenStatusBar) }
    }
    @objc dynamic public var msgMatchKeywords: String? {
        get { string(forKey: Keys.msgMatchKeywords) }
        set { set(newValue, forKey: Keys.msgMatchKeywords) }
    }
    @objc dynamic public var msgCodeMatchPattern: String? {
        get { string(forKey: Keys.msgCodeMatchPattern) }
        set { set(newValue, forKey: Keys.msgCodeMatchPattern) }
    }
    @objc dynamic public var pythonSciprt: String? {
        get { string(forKey: Keys.pythonSciprt) }
        set { set(newValue, forKey: Keys.pythonSciprt) }
    }
}

struct ClipboardController {
    static let clipboard = Clipboard.init()
}


@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
//    let codePattern = "\\b([0-9]{4,8})\\b"
    var timer: Timer? = nil
    let dbPath = "Messages/chat.db"
    // 数据库连接
    var db: OpaquePointer?
    // 最新一条短信的接收时间
    var updateTime: Int32 = 0
    // 记录上一次的 是否隐藏状态栏图标 缓存情况
    // applicationDidFinishLaunching 比 applicationDidBecomeActive 先执行
    // 可能就会存在我最后设置的是不显示, 再次启动此应用时先调用 applicationDidFinishLaunching 设置不显示
    // 再执行 applicationDidBecomeActive 就又显示的情况
    var visibleStatusBarCacheValue = false
    
    private lazy var settingsWindowController = SettingsWindowController(
        panes: [
            GeneralSettingViewController(),
            RegexSettingViewController()
        ]
    )
    
    // 创建状态栏按钮
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var hiddenStatusBarMenuItem: NSMenuItem!
    @IBOutlet weak var settingMenuItem : NSMenuItem!
    
    private var fullDiskAccessAlert: NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "“MacCopier“启动失败, 可能是没有设置“完全磁盘访问权限”。"
        alert.informativeText = "在“系统偏好设置”中的“安全性和隐私”设置中授予此应用程序权限, 设置完成后请重新打开“MacCopier“"
        alert.addButton(withTitle: "拒绝")
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.icon = NSImage(named: "NSSecurity")
        return alert
    }
    let fullDiskAccessURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )
    
    func applicationWillBecomeActive(_ notification: Notification) {
        if !self.visibleStatusBarCacheValue {
            self.visibleStatusBarCacheValue = true
        } else {
            self.changeStatusBarVisible(visible: true)
        }
    }
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.menu = menu
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusIcon")
        }
        hiddenStatusBarMenuItem.state = UserDefaults.standard.hiddenStatusBar ? .on : .off
        self.visibleStatusBarCacheValue = !UserDefaults.standard.hiddenStatusBar
        self.changeStatusBarVisible(visible: !UserDefaults.standard.hiddenStatusBar)
        
        db = openDatabase()
        if (db == nil) {
            return
        }
        self.updateTime = getLatestMessageTime()
        
        timer = Timer.init(timeInterval: 2, repeats: true) { (t) in
            let latestMessageTime = self.getLatestMessageTime()
            if self.updateTime != latestMessageTime {
                self.updateTime = latestMessageTime
                self.getLatestMessageCode()
            }
        }
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
        timer!.fire()
    }
    
    func changeStatusBarVisible(visible: Bool) {
        statusItem.isVisible = visible
        UserDefaults.standard.hiddenStatusBar = !visible
        hiddenStatusBarMenuItem.state = visible ? .off : .on
        if visible {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    @IBAction func quitApp(_ sender: Any) {
        if timer != nil {
            timer!.invalidate()
        }
        if db != nil {
            sqlite3_finalize(db)
            print("释放 sqlite 连接")
        }
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func openSettingWindow(_ sender: Any) {
        settingsWindowController.show()
        settingsWindowController.window?.orderFrontRegardless()
    }
    
    @IBAction func openAboutWindow(_ sender: Any) {
        let about = About()
        about.openAbout(sender)
    }
    
    @IBAction func hiddenStatusBar(_ sender: Any) {
        let visible = hiddenStatusBarMenuItem.state == .on
        self.changeStatusBarVisible(visible: visible)
        if !visible {
            // 隐藏状态栏图标后需要失去 MacCopier 的窗口激活状态
            // 否则在没有点击其它窗口的情况下, 再次打开 MacCopier 就不能执行 applicationWillBecomeActive 事件了
            NSApplication.shared.hide(nil)
        }
    }
    
    func getLatestMessageCode() {
        let message = getLatestMessage()
        if message != nil {
            let msgText = message!.text
            let msgMatchKeywords = UserDefaults.standard.msgMatchKeywords ?? ""
            var matched = false
            if msgMatchKeywords == "" {
                matched = true
            } else {
                for keyword in msgMatchKeywords.split(separator: ";").map({ String($0) }) {
                    matched = matched || msgText.contains(keyword)
                }
            }
            
            if matched {
                do {
                    let pythonSciprt = UserDefaults.standard.pythonSciprt ?? ""
                    var smsCode = "", alwaysRegex = true
                    if pythonSciprt != "" {
                        // 执行python脚本解析
                        smsCode =  runPythonScript(pythonScript: pythonSciprt, sms: msgText) ?? ""
                        if smsCode == "ERROR" || smsCode == "NOT_VALID" {
                            smsCode = ""
                        }
                        if smsCode == "NOT_VALID" {
                            alwaysRegex = false
                        }
                    }
                    if alwaysRegex && smsCode == "" {
                        // 正则表达式解析
                        let pattern = UserDefaults.standard.msgCodeMatchPattern ?? Constants.DEFAULT_MSG_CODE_MATCH_PATTERN
                        let re = try NSRegularExpression(pattern: pattern)
                        let results = re.matches(in: msgText, range: NSRange(msgText.startIndex..., in:msgText))
                        for result in results {
                            smsCode = (msgText as NSString).substring(with: result.range)
                            break
                        }
                    }
                    if smsCode != "" {
                        ClipboardController.clipboard.copy(text: smsCode)
                        if UserDefaults.standard.autoPaste {
                            ClipboardController.clipboard.paste()
                        }
                    }
                } catch {
                    print("Regex Error.")
                }
            }
        }
    }
    
    func getLatestMessageTime() -> Int32 {
        let message = getLatestMessage()
        if message == nil {
            return 0
        } else {
            return message!.messageDate
        }
    }
    
    
    func openDatabase() -> OpaquePointer? {
        var db: OpaquePointer?
        var path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        path = (path as NSString).appendingPathComponent(dbPath)
        
        if sqlite3_open(path, &db) == SQLITE_OK {
            return db
        } else {
            DispatchQueue.main.async(execute: showFullDiskAccessInquiryWindow)
            return nil
        }
    }
    
    func getLatestMessage() -> Message? {
        let sql = """
        select
            (message.date / 1000000000 + 978307200) AS message_date,
            message.text
        from
            message
                left join chat_message_join
                        on chat_message_join.message_id = message.ROWID
                left join chat
                        on chat.ROWID = chat_message_join.chat_id
                left join handle
                        on message.handle_id = handle.ROWID
        where
            is_from_me = 0
            and text is not null
            and length(text) > 0
            and (
                text glob '*[0-9][0-9][0-9][0-9]*'
                or text glob '*[0-9][0-9][0-9][0-9][0-9]*'
                or text glob '*[0-9][0-9][0-9][0-9][0-9][0-9]*'
                or text glob '*[0-9][0-9][0-9][0-9][0-9][0-9][0-9]*'
                or text glob '*[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*'
            )
        order by
            message.date desc
        limit 1
        """
        var statement: OpaquePointer?
        var message: Message?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let messageDate = sqlite3_column_int(statement, 0)
                let text = String(cString: sqlite3_column_text(statement, 1))
                
                message = Message(messageDate: messageDate, text: text)
            } else {
                print("消息查询失败")
            }
        }
        sqlite3_finalize(statement)
        
        return message
    }
    
    
    func runPythonScript(pythonScript: String,sms: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = ["-c", pythonScript, sms]
        let outputPipe = Pipe()
        task.standardOutput = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output
        } catch {
            print("Error running Python script: \(error)")
            return "ERROR"
        }
    }
    
    
    func showFullDiskAccessInquiryWindow() {
        if fullDiskAccessAlert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn {
            if let url = fullDiskAccessURL {
                NSWorkspace.shared.open(url)
            }
        }
        
        // 无论如何都退出吧
        // 目前我的能力有限, 不能做到设置完权限后再次连接数据库打开
        // 也希望有能力的小伙伴提交 PR 完善
        // 包括在开启 自动粘贴 选项时也会有这个问题
        NSApplication.shared.terminate(self)
    }
}


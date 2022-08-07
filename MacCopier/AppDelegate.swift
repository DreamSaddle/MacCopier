import Cocoa
import SwiftUI
import SQLite3
import LaunchAtLogin

class Message {
    var messageDate: Int32
    var text: String
    init(messageDate: Int32, text: String) {
        self.messageDate = messageDate
        self.text = text
    }
}

// 扩展 UserDefaults 存储用户数据
extension UserDefaults {
    public struct Keys {
        static let autoPaste = "autoPaste"
        static let hiddenStatusBar = "hiddenStatusBar"
    }
    
    struct ConfigValues {
        static let autoPaste = false
        static let hiddenStatusBar = false
    }
    
    @objc dynamic public var autoPaste: Bool {
        get { bool(forKey: Keys.autoPaste) }
        set { set(newValue, forKey: Keys.autoPaste) }
    }
    @objc dynamic public var hiddenStatusBar: Bool {
        get { bool(forKey: Keys.hiddenStatusBar) }
        set { set(newValue, forKey: Keys.hiddenStatusBar) }
    }
}


@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 创建状态栏按钮
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var autoPasteMenuItem: NSMenuItem!
    @IBOutlet weak var launchOnLoginMenuItem: NSMenuItem!
    @IBOutlet weak var hiddenStatusBarMenuItem: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    let codePattern = "([0-9]{4,8})"
    
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
    let clipboard = Clipboard.init()
    
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
        launchOnLoginMenuItem.state = LaunchAtLogin.isEnabled ? .on : .off
        autoPasteMenuItem.state = UserDefaults.standard.autoPaste ? .on : .off
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
    }
    
    @IBAction func quitApp(_ sender: Any) {
        if timer != nil {
            timer!.invalidate()
        }
        if db != nil {
            sqlite3_finalize(db)
        }
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func changeAutoPaste(_ sender: Any) {
        if autoPasteMenuItem.state == .off && self.clipboard.checkAutoPastePermission() == false {
            return
        }
        autoPasteMenuItem.state = autoPasteMenuItem.state == .on ? .off : .on
        UserDefaults.standard.autoPaste = (autoPasteMenuItem.state == .on)
    }
    
    @IBAction func changeLaunchOnLogin(_ sender: Any) {
        launchOnLoginMenuItem.state = launchOnLoginMenuItem.state == .on ? .off : .on
        LaunchAtLogin.isEnabled = (launchOnLoginMenuItem.state == .on)
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
            if msgText.contains("code") || msgText.contains("码") || msgText.contains("コード") {
                do {
                    let re = try NSRegularExpression(pattern: codePattern, options: [])
                    let results = re.matches(in: msgText, range: NSRange(location: 0, length: msgText.count))
                    for result in results {
                        let code = (msgText as NSString).substring(with: result.range)
                        self.clipboard.copy(text: code)
                        if UserDefaults.standard.autoPaste {
                            self.clipboard.paste()
                        }
                        
                        break
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


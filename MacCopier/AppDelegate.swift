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

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // 创建状态栏按钮
    @IBOutlet weak var menu: NSMenu!
    // 登录时启动选项菜单
    @IBOutlet weak var launchOnLoginMenuItem: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    let codePattern = "([0-9]{4,8})"
    
    var timer: Timer? = nil
    var dbPath = "Messages/chat.db"
    // 数据库连接
    var db: OpaquePointer?
    // 最新一条短信的接收时间
    var updateTime: Int32 = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.menu = menu
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusIcon")
        }
        
        launchOnLoginMenuItem.state = LaunchAtLogin.isEnabled ? .on : .off
        
        // 打开数据库连接
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

    @IBAction func quitApp(_ sender: Any) {
        if timer != nil {
            timer!.invalidate()
        }
        if db != nil {
            sqlite3_finalize(db)
        }
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func changeLaunchOnLogin(_ sender: Any) {
        launchOnLoginMenuItem.state = launchOnLoginMenuItem.state == .on ? .off : .on
        LaunchAtLogin.isEnabled = (launchOnLoginMenuItem.state == .on)
    }
    
    @IBAction func openAboutWindow(_ sender: Any) {
        let about = About()
        about.openAbout(sender)
    }
    
    func getLatestMessageCode() {
        let message = getLatestMessage()
        if message != nil {
            let msgText = message!.text
            if msgText.contains("code") || msgText.contains("码") {
                do {
                    let re = try NSRegularExpression(pattern: codePattern, options: [])
                    let results = re.matches(in: msgText, range: NSRange(location: 0, length: msgText.count))
                    for result in results {
                        let code = (msgText as NSString).substring(with: result.range)
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(code, forType: .string)
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
            let alert = NSAlert.init()
            alert.messageText = "数据库打开失败"
            alert.informativeText = "请检查应用是否具有 完整磁盘访问权限！"
            alert.addButton(withTitle: "确定")
            alert.runModal()
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
}


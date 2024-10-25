import Cocoa
import SwiftUI
import Carbon

// 添加一个全局变量来存储 AppDelegate 实例
var globalAppDelegate: AppDelegate?

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var contentView: ContentView!
    var eventMonitor: Any?
    var settingsMenu: NSMenu!
    var showSystemApps: Bool {
        get {
            !UserDefaults.standard.bool(forKey: "hideSystemApps")
        }
        set {
            UserDefaults.standard.set(!newValue, forKey: "hideSystemApps")
        }
    }
    var localEventMonitor: Any?
    var globalEventMonitor: Any?
    var hotKeyRef: EventHotKeyRef?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置全局 AppDelegate 实例
        globalAppDelegate = self
        
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusBarItem()
        setupPopover()
        setupGlobalShortcut()  // 确保在应用启动时设置全局快捷键
        setupSettingsMenu()
    }
    
    func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            if let appIcon = NSImage(named: "AppIcon") {
                let resizedIcon = resizeImage(image: appIcon, w: 22, h: 22)
                button.image = resizedIcon
            } else {
                button.image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App Launcher")
            }
            
            button.action = #selector(togglePopover)
        }
    }
    
    func setupPopover() {
        contentView = ContentView(
            onQuit: quitApp,
            onRefresh: refreshApplications,
            onShowSettings: showSettingsMenu  // 使用 showSettingsMenu 方法
        )
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
    }
    
    func setupGlobalShortcut() {
        // 从 UserDefaults 获取保存的快捷键，如果没有则使用默认值
        let savedShortcut = UserDefaults.standard.string(forKey: "globalShortcut") ?? "⌃E"
        print("Setting up global shortcut... \(savedShortcut)")
    
        // 解析快捷键字符串
        let (keyCode, modifiers) = parseShortcut(savedShortcut)
        print("keyCode \(keyCode), modifier \(modifiers)")
        
        // 首先，移除现有的快捷键
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("MYHT".utf16.reduce(0, {$0 << 8 + UInt32($1)}))
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        // 修改这里的闭包
        let hotKeyHandler: EventHandlerUPP = { (_, _, _) -> OSStatus in
            print("Hot key event received!")
            DispatchQueue.main.async {
                if let appDelegate = globalAppDelegate {
                    appDelegate.togglePopover()
                }
            }
            return noErr
        }

        // 安装事件处理程序
        let installResult = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, nil)
        if installResult == noErr {
            print("Event handler installed successfully")
        } else {
            print("Failed to install event handler: \(installResult)")
        }

        // 注册热键
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hot key: \(status)")
        } else {
            print("Hot key registered successfully: \(savedShortcut)")
        }
    }
    
    func setupSettingsMenu() {
        settingsMenu = NSMenu()
        
        settingsMenu.addItem(NSMenuItem(title: "打开设置", action: #selector(openSettings), keyEquivalent: ","))

        let showSystemAppsItem = NSMenuItem(title: "显示系统应用", action: #selector(toggleShowSystemApps), keyEquivalent: "")
        showSystemAppsItem.state = showSystemApps ? .on : .off
        settingsMenu.addItem(showSystemAppsItem)
        
        settingsMenu.addItem(NSMenuItem(title: "刷新应用列表", action: #selector(refreshApplications), keyEquivalent: "r"))
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc func togglePopover() {
        print("togglePopover called")
        if let button = statusBarItem.button {
            if popover.isShown {
                print("Closing popover")
                popover.performClose(nil)
            } else {
                print("Showing popover")
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
                contentView.refreshApplications()
            }
        } else {
            print("statusBarItem.button is nil")
        }
    }
    
    @objc func showSettingsMenu() {
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(settingsMenu, with: event, for: statusBarItem.button!)
        }
    }
    
    @objc func quitApp() {
        print("quitApp....")
        NSApplication.shared.terminate(nil)
    }
    
    @objc func refreshApplications() {
        contentView.refreshApplications()
    }
    
    @objc func toggleShowSystemApps(_ sender: NSMenuItem) {
        showSystemApps.toggle()
        sender.state = showSystemApps ? .on : .off
        refreshApplications()
    }
    
    // 辅助函数：调整图像大小
    func resizeImage(image: NSImage, w: Int, h: Int) -> NSImage {
        let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    deinit {
        // 移除热键
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "设置"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.center()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateGlobalShortcut(_ shortcut: String) {
        print("Updating global shortcut to: \(shortcut)")
        
        // 首先，移除现有的快捷键
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        // 保存新的快捷键到 UserDefaults
        UserDefaults.standard.set(shortcut, forKey: "globalShortcut")
        
        // 重新设置全局快捷键
        setupGlobalShortcut()
    }

    func parseShortcut(_ shortcut: String) -> (UInt32, UInt32) {
        var keyCode: UInt32 = 0
        var modifiers: UInt32 = 0
        
        // 分离修饰键和主键
        let components = shortcut.components(separatedBy: CharacterSet.letters)
        let modifierStr = components[0]
        let mainKey = shortcut.components(separatedBy: modifierStr)[1]
        
        // 解析修饰键
        if modifierStr.contains("⌘") { modifiers |= UInt32(cmdKey) }
        if modifierStr.contains("⌥") { modifiers |= UInt32(optionKey) }
        if modifierStr.contains("⌃") { modifiers |= UInt32(controlKey) }
        if modifierStr.contains("⇧") { modifiers |= UInt32(shiftKey) }
        
        // 获取主键的键码
        let mainKeyStr = mainKey.uppercased()
        switch mainKeyStr {
        case "A": keyCode = 0
        case "B": keyCode = 11
        case "C": keyCode = 8
        case "D": keyCode = 2
        case "E": keyCode = 14
        case "F": keyCode = 3
        case "G": keyCode = 5
        case "H": keyCode = 4
        case "I": keyCode = 34
        case "J": keyCode = 38
        case "K": keyCode = 40
        case "L": keyCode = 37
        case "M": keyCode = 46
        case "N": keyCode = 45
        case "O": keyCode = 31
        case "P": keyCode = 35
        case "Q": keyCode = 12
        case "R": keyCode = 15
        case "S": keyCode = 1
        case "T": keyCode = 17
        case "U": keyCode = 32
        case "V": keyCode = 9
        case "W": keyCode = 13
        case "X": keyCode = 7
        case "Y": keyCode = 16
        case "Z": keyCode = 6
        default: break
        }
        
        return (keyCode, modifiers)
    }
}

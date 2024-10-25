//
//  ContentView.swift
//  MacMirroring
//
//  Created by ddxx on 2024/10/18.
//

import SwiftUI
import AppKit
import ApplicationServices

struct ContentView: View {
    @State private var applications: [Application] = []
    @State private var pinnedApps: [Application] = []
    @State private var showSettingsMenu: Bool = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    @AppStorage("hideSystemApps") private var hideSystemApps = false
    var onQuit: () -> Void
    var onRefresh: () -> Void
    var onShowSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索应用", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                Button(action: {
                    onShowSettings()
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 5)

            Divider()
                .padding(.horizontal, 10)

            // 应用列表
            List {
                Section(header: Text("置顶应用")) {
                    ForEach(pinnedApps) { app in
                        appRow(for: app, isPinned: true)
                    }
                }
                
                Section(header: Text("所有应用")) {
                    ForEach(sortedApplications) { app in
                        if !pinnedApps.contains(app) {
                            appRow(for: app, isPinned: false)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear(perform: loadApplications)
    }

    var filteredApplications: [Application] {
        applications.filter { app in
            let matchesSearch = searchText.isEmpty || app.name.lowercased().contains(searchText.lowercased())
            let isNotSystemApp = !hideSystemApps || !app.path.starts(with: "/System")
            return matchesSearch && isNotSystemApp
        }
    }

    var sortedApplications: [Application] {
        filteredApplications.sorted { (app1, app2) -> Bool in
            if app1.isRunning != app2.isRunning {
                return app1.isRunning
            }
            return app1.name < app2.name
        }
    }

    func appRow(for app: Application, isPinned: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(app.isRunning ? Color.green : Color.clear)
                .frame(width: 8, height: 8)
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)  // 稍微增加应用图标大小
            Text(app.name)
                .font(.system(size: 14))
                .lineLimit(1)
            Spacer()
            HStack(spacing: 10) {  // 增加按钮之间的间距
                if app.isRunning {
                    Button(action: {
                        openApplication(app.path)
                    }) {
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("打开")
                }
                Button(action: {
                    launchApplication(app.path)
                }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .help("启动")
                
                Button(action: {
                    togglePinned(app)
                }) {
                    Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                        .foregroundColor(isPinned ? .blue : .gray)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .help(isPinned ? "取消置顶" : "置顶")
            }
        }
        .padding(.vertical, 4)  // 增加垂直内边距
        .padding(.horizontal, 8)
    }

    func loadApplications() {
        // 从 /Applications 获取应用
        if let apps = getApplications(in: URL(fileURLWithPath: "/Applications")) {
            applications.append(contentsOf: apps)
        }
        
        // 获取系统应用
        if let systemApps = getApplications(in: URL(fileURLWithPath: "/System/Applications")) {
            applications.append(contentsOf: systemApps)
        }
        
        // 排序
        applications.sort { $0.name < $1.name }
        
        // 加载置顶应用
        loadPinnedApps()
        
        // 在加载完应用后，检查每个应用的运行状态
        refreshApplications()
    }
    
    func getApplications(in directory: URL) -> [Application]? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return nil
        }
        
        var apps: [Application] = []
        for case let fileURL as URL in enumerator {
            if let resources = try? fileURL.resourceValues(forKeys: [.isApplicationKey]),
               let isApplication = resources.isApplication, isApplication {
                if let app = Application(fileURL: fileURL) {
                    apps.append(app)
                }
            }
        }
        return apps
    }
    
    func togglePinned(_ app: Application) {
        if let index = pinnedApps.firstIndex(of: app) {
            pinnedApps.remove(at: index)
        } else {
            pinnedApps.append(app)
        }
        savePinnedApps()
    }
    
    func loadPinnedApps() {
        if let savedPinnedApps = UserDefaults.standard.data(forKey: "pinnedApps") {
            do {
                pinnedApps = try JSONDecoder().decode([Application].self, from: savedPinnedApps)
            } catch {
                print("Error decoding pinned apps: \(error)")
            }
        }
    }
    
    func savePinnedApps() {
        do {
            let encodedData = try JSONEncoder().encode(pinnedApps)
            UserDefaults.standard.set(encodedData, forKey: "pinnedApps")
        } catch {
            print("Error encoding pinned apps: \(error)")
        }
    }

    func launchApplication(_ path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", "-a", path]
        do {
            try task.run()
        } catch {
            print("无法启动应用：\(error.localizedDescription)")
        }
    }

    func openApplication(_ path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", path]
        do {
            try task.run()
        } catch {
            print("无法打开应用：\(error.localizedDescription)")
        }
    }

    func refreshApplications() {
        for i in 0..<applications.count {
            applications[i].checkRunningStatus()
        }
    }

    func quitApplication(_ path: String) {
        
        let bundleIdentifier = Bundle(path: path)?.bundleIdentifier
        if let bundleIdentifier = bundleIdentifier {
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                app.terminate()
                
                DispatchQueue.main.async {
                    // 等待一段时间后刷新应用状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.refreshApplications()
                    }
                }
            }
        }
    }

}

struct Application: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let category: String
    var isRunning: Bool = false
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
    
    init?(fileURL: URL) {
        self.id = UUID()
        self.path = fileURL.path
        self.name = fileURL.deletingPathExtension().lastPathComponent
        self.category = Application.determineCategory(for: fileURL)
        self.checkRunningStatus()
    }
    
    mutating func checkRunningStatus() {
        let runningApplications = NSWorkspace.shared.runningApplications
        self.isRunning = runningApplications.contains { $0.bundleIdentifier == self.bundleIdentifier }
    }
    
    var bundleIdentifier: String? {
        Bundle(path: self.path)?.bundleIdentifier
    }
    
    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.id == rhs.id
    }
    
    static func determineCategory(for fileURL: URL) -> String {
        // Implement category determination logic here
        return ""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(onQuit: {
            // 这里可以是一个空闭包，因为这只是预览
            print("Quit action in preview")
        }, onRefresh: {
            print("Refresh action in preview")
        }, onShowSettings: {
            // 这里可以是一个空闭包，因为这只是预览
            print("Show settings in preview")
        })
    }
}

// 创建一个紧凑的按钮样式
struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

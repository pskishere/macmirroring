import SwiftUI
import Carbon

struct SettingsView: View {
    @AppStorage("globalShortcut") private var globalShortcut = "⌃E"
    @State private var isRecording = false
    @State private var tempShortcut: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷键设置")
                .font(.headline)
            HStack {
                Text("全局快捷键:")
                    .foregroundColor(.secondary)
                Spacer()
                if isRecording {
                    Text("请按下新的快捷键...")
                        .foregroundColor(.blue)
                } else {
                    Text(globalShortcut)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Button(action: {
                isRecording.toggle()
                if isRecording {
                    tempShortcut = nil
                }
            }) {
                Text(isRecording ? "取消" : "修改快捷键")
                    .frame(maxWidth: .infinity)
            }.padding(.vertical, 8)
            
            if let temp = tempShortcut {
                HStack {
                    Text("新快捷键:")
                        .foregroundColor(.secondary)
                    Text(temp)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .cornerRadius(4)
                    Spacer()
                    Button("应用") {
                        globalShortcut = temp
                        isRecording = false
                        updateGlobalShortcut(globalShortcut)
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 180)
        .background(
            SettingsKeyboardEventHandler(isRecording: $isRecording, shortcut: $tempShortcut)
        )
    }
    
    func updateGlobalShortcut(_ shortcut: String) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateGlobalShortcut(shortcut)
        }
    }
}

struct SettingsKeyboardEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: String?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.allowedTouchTypes = []
        
        // 添加事件监听器
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecording {
                self.handleKeyEvent(event)
                return nil // 阻止事件继续传递
            }
            return event
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func handleKeyEvent(_ event: NSEvent) {
        var modifiers = ""
        if event.modifierFlags.contains(.command) { modifiers += "⌘" }
        if event.modifierFlags.contains(.option) { modifiers += "⌥" }
        if event.modifierFlags.contains(.control) { modifiers += "⌃" }
        if event.modifierFlags.contains(.shift) { modifiers += "⇧" }
        
        if let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty {
            shortcut = modifiers + key
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

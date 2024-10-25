import SwiftUI
import Carbon

struct ShortcutSettingsView: View {
    @Binding var shortcutKey: String
    @State private var isRecording = false
    @State private var tempShortcut: String?
    
    var body: some View {
        VStack {
            HStack {
                Text("当前快捷键:")
                Spacer()
                Text(shortcutKey)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                isRecording.toggle()
                if isRecording {
                    tempShortcut = nil
                }
            }) {
                Text(isRecording ? "点击停止" : "修改快捷键")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            if isRecording {
                Text("请按下新的快捷键组合")
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            
            if let temp = tempShortcut {
                HStack {
                    Text("新快捷键: \(temp)")
                    Spacer()
                    Button("用") {
                        shortcutKey = temp
                        isRecording = false
                        // 这里需要调用一个函数来实际更新全局快捷键
                        updateGlobalShortcut(shortcutKey)
                    }
                }
                .padding(.top)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
    
    func updateGlobalShortcut(_ shortcut: String) {
        // 这里需要实现更新全局快捷键的逻辑
        // 可能需要调用 AppDelegate 中的方法
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateGlobalShortcut(shortcut)
        }
    }
}

struct KeyboardEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: String?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.allowedTouchTypes = []  // 替换 acceptsTouchEvents
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: KeyboardEventHandler
        
        init(_ parent: KeyboardEventHandler) {
            self.parent = parent
        }
        
        @objc func keyDown(with event: NSEvent) {
            guard parent.isRecording else { return }
            
            var modifiers = ""
            if event.modifierFlags.contains(.command) { modifiers += "⌘" }
            if event.modifierFlags.contains(.option) { modifiers += "⌥" }
            if event.modifierFlags.contains(.control) { modifiers += "⌃" }
            if event.modifierFlags.contains(.shift) { modifiers += "⇧" }
            
            let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
            
            parent.shortcut = modifiers + key
        }
    }
}

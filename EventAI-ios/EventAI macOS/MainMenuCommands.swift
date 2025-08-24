import SwiftUI

struct MainMenuCommands: Commands {
    var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("Quick Create Event...") {
                // This will trigger the menu bar popover
                NotificationCenter.default.post(name: .toggleQuickCreate, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])
            
            Button("Open Main Window") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "EventAI" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // Create new window if none exists
                    NSApp.sendAction(Selector(("newDocument:")), to: nil, from: nil)
                }
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        
        // Edit menu additions
        CommandGroup(after: .pasteboard) {
            Divider()
            
            Button("Paste and Convert") {
                // Get text from pasteboard and trigger conversion
                let pasteboard = NSPasteboard.general
                if let text = pasteboard.string(forType: .string) {
                    NotificationCenter.default.post(
                        name: .pasteAndConvert,
                        object: nil,
                        userInfo: ["text": text]
                    )
                }
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }
        
        // View menu
        CommandGroup(after: .toolbar) {
            Divider()
            
            Button("Toggle Menu Bar Icon") {
                NotificationCenter.default.post(name: .toggleMenuBar, object: nil)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
            
            Button("Always on Top") {
                NotificationCenter.default.post(name: .toggleAlwaysOnTop, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
        }
        
        // Help menu additions
        CommandGroup(replacing: .help) {
            Button("EventAI Help") {
                if let url = URL(string: "https://eventai.leveluplife.app/help") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Button("Keyboard Shortcuts") {
                NotificationCenter.default.post(name: .showShortcuts, object: nil)
            }
            .keyboardShortcut("?", modifiers: [.command])
            
            Divider()
            
            Button("Report Issue") {
                if let url = URL(string: "https://github.com/EventAI/EventAI/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Button("EventAI Website") {
                if let url = URL(string: "https://eventai.leveluplife.app") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        // Window menu additions
        CommandGroup(after: .windowArrangement) {
            Divider()
            
            Button("Reset Window Size") {
                if let window = NSApp.keyWindow {
                    window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 800, height: 600), display: true)
                }
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let toggleQuickCreate = Notification.Name("toggleQuickCreate")
    static let pasteAndConvert = Notification.Name("pasteAndConvert")
    static let toggleMenuBar = Notification.Name("toggleMenuBar")
    static let toggleAlwaysOnTop = Notification.Name("toggleAlwaysOnTop")
    static let showShortcuts = Notification.Name("showShortcuts")
}

// MARK: - Keyboard Shortcuts Helper View
struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRow(key: "⌘N", description: "Quick Create Event")
                ShortcutRow(key: "⌘O", description: "Open Main Window")
                ShortcutRow(key: "⇧⌘V", description: "Paste and Convert")
                ShortcutRow(key: "⌥⌘M", description: "Toggle Menu Bar Icon")
                ShortcutRow(key: "⌥⌘T", description: "Always on Top")
                ShortcutRow(key: "⌘?", description: "Show This Help")
                ShortcutRow(key: "⌘0", description: "Reset Window Size")
                ShortcutRow(key: "⌘,", description: "Open Preferences")
                ShortcutRow(key: "⌘Q", description: "Quit EventAI")
            }
        }
        .padding()
        .frame(width: 300, height: 350)
    }
}

struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .leading)
            
            Text(description)
                .font(.caption)
            
            Spacer()
        }
    }
}
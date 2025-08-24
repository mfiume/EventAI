import SwiftUI
import AppKit

@main
struct EventAI_macOS: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var apiService = SharedAPIService.shared
    @StateObject private var calendarService = SharedCalendarService.shared
    
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(apiService)
                .environmentObject(calendarService)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            MainMenuCommands()
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(apiService)
        }
    }
}

// MARK: - App Delegate for Menu Bar Integration
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var shortcutsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotificationObservers()
    }
    
    private func setupMenuBar() {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "calendar.badge.plus", accessibilityDescription: "EventAI")
            statusButton.action = #selector(togglePopover)
            statusButton.target = self
            statusButton.toolTip = "EventAI - Quick Create Event"
        }
        
        // Create popover with environment objects
        let quickCreateView = QuickCreateView()
            .environmentObject(SharedAPIService.shared)
            .environmentObject(SharedCalendarService.shared)
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 300)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: quickCreateView)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePopover),
            name: .toggleQuickCreate,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarToggle),
            name: .toggleMenuBar,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlwaysOnTop),
            name: .toggleAlwaysOnTop,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showKeyboardShortcuts),
            name: .showShortcuts,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteAndConvert),
            name: .pasteAndConvert,
            object: nil
        )
    }
    
    @objc private func togglePopover() {
        guard let statusButton = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
            }
        }
    }
    
    @objc private func handleMenuBarToggle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let show = userInfo["show"] as? Bool else { return }
        
        if show {
            if statusItem == nil {
                setupMenuBar()
            }
        } else {
            statusItem = nil
        }
    }
    
    @objc private func handleAlwaysOnTop(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let enabled = userInfo["enabled"] as? Bool else { return }
        
        for window in NSApp.windows {
            if enabled {
                window.level = .floating
            } else {
                window.level = .normal
            }
        }
    }
    
    @objc private func showKeyboardShortcuts() {
        if shortcutsWindow?.isVisible == true {
            shortcutsWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let shortcutsView = KeyboardShortcutsView()
        let hostingController = NSHostingController(rootView: shortcutsView)
        
        shortcutsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        shortcutsWindow?.contentViewController = hostingController
        shortcutsWindow?.title = "Keyboard Shortcuts"
        shortcutsWindow?.center()
        shortcutsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func handlePasteAndConvert(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String else { return }
        
        // Find the main window and send the text to it
        // This would need to be implemented with proper inter-view communication
        print("Paste and convert: \(text)")
    }
}
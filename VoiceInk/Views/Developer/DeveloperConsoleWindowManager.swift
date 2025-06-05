import SwiftUI
import AppKit

class DeveloperConsoleWindowManager: ObservableObject {
    static let shared = DeveloperConsoleWindowManager()
    
    private var consoleWindow: NSWindow?
    @Published var isConsoleVisible = false
    
    private init() {}
    
    func showConsole() {
        if consoleWindow == nil {
            createConsoleWindow()
        }
        
        consoleWindow?.makeKeyAndOrderFront(nil)
        consoleWindow?.orderFrontRegardless()
        isConsoleVisible = true
    }
    
    func hideConsole() {
        consoleWindow?.orderOut(nil)
        isConsoleVisible = false
    }
    
    func toggleConsole() {
        if isConsoleVisible {
            hideConsole()
        } else {
            showConsole()
        }
    }
    
    private func createConsoleWindow() {
        let contentView = DeveloperConsoleView()
            .environmentObject(self)
            .frame(minWidth: 600, minHeight: 400)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create window with proper initial size
        let initialRect = NSRect(x: 100, y: 100, width: 800, height: 600)
        
        consoleWindow = NSWindow(
            contentRect: initialRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        consoleWindow?.title = "VoiceInk Developer Console"
        consoleWindow?.contentViewController = hostingController
        consoleWindow?.isReleasedWhenClosed = false
        consoleWindow?.level = .floating
        consoleWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set size constraints
        consoleWindow?.minSize = NSSize(width: 600, height: 400)
        consoleWindow?.maxSize = NSSize(width: 1400, height: 1000)
        
        // Force the window to respect the initial size
        consoleWindow?.setFrame(initialRect, display: false)
        
        // Center the window initially
        consoleWindow?.center()
        
        // Handle window close
        consoleWindow?.delegate = DeveloperConsoleWindowDelegate(manager: self)
        
        // Make window draggable by background
        consoleWindow?.isMovableByWindowBackground = true
        
        // Set appearance
        consoleWindow?.appearance = NSApp.effectiveAppearance
        consoleWindow?.titlebarAppearsTransparent = false
        consoleWindow?.backgroundColor = NSColor.windowBackgroundColor
        
        // Ensure proper sizing
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
    }
}

// MARK: - Window Delegate
private class DeveloperConsoleWindowDelegate: NSObject, NSWindowDelegate {
    weak var manager: DeveloperConsoleWindowManager?
    
    init(manager: DeveloperConsoleWindowManager) {
        self.manager = manager
    }
    
    func windowWillClose(_ notification: Notification) {
        manager?.isConsoleVisible = false
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        manager?.isConsoleVisible = true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Keep the window visible even when it loses focus
        // This allows interaction with the main app while console is open
    }
}

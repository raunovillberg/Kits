import Cocoa
import SwiftUI
import os.log
import Combine

// Import ViewModel
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var settingsPopover: NSPopover?
    private var gitScanner: GitScanner!
    private var testWindow: NSWindow?
    private var settings: Settings!
    private var launchAtLoginHelper: LaunchAtLoginHelper!
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.general.info("Kits launching...")
        
        // Create dependencies
        let settings = Settings()
        let gitScanner = GitScanner(settings: settings)
        let launchAtLoginHelper = LaunchAtLoginHelper()
        
        self.settings = settings
        self.gitScanner = gitScanner
        self.launchAtLoginHelper = launchAtLoginHelper
        
        // Refresh the launch agent path in case the app moved
        launchAtLoginHelper.updatePathIfNeeded()
        
        // Create the ViewModel for dependency injection
        let viewModel = ContentViewModel(gitScanner: gitScanner, settings: settings)
        
        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: CGFloat(settings.popoverWidth), height: CGFloat(settings.popoverHeight))
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environment(viewModel)
        )
        self.popover = popover

        if ProcessInfo.processInfo.environment["KITS_UI_TESTING"] == "1" {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: CGFloat(settings.popoverWidth), height: CGFloat(settings.popoverHeight)),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Kits"
            window.contentView = NSHostingView(rootView: ContentView().environment(viewModel))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.testWindow = window
        }
        
        // Create the status bar item with right-click menu
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Git Repositories")
            button.setAccessibilityLabel("Kits")
            button.action = #selector(handleStatusBarClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Observe scanning state to update status bar icon
        gitScanner.isScanningPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.updateStatusBarIcon(isScanning: isScanning)
            }
            .store(in: &cancellables)
        
        // Start scanning only if a path is set
        if settings.rootFolderPath != nil {
            gitScanner.startScanning()
        }
    }
    
    /// Updates the status bar icon - shows blue dot overlay when scanning
    private func updateStatusBarIcon(isScanning: Bool) {
        guard let button = statusBarItem.button else { return }
        
        // Use the system symbol - this naturally handles Light/Dark mode
        // when isTemplate is true (which is the default for system symbols)
        let baseImage = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Git Repositories")
        
        if let compositeImage = createStatusBarIcon(baseImage: baseImage, showDot: isScanning) {
            button.image = compositeImage
        }
    }
    
    /// Creates status bar icon with optional blue dot.
    /// Returns a template image so macOS handles the black/white inversion automatically.
    private func createStatusBarIcon(baseImage: NSImage?, showDot: Bool) -> NSImage? {
        guard let baseImage = baseImage else { return nil }
        
        let size = NSSize(width: Constants.UI.statusBarIconSize, height: Constants.UI.statusBarIconSize)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 1. Draw the base icon
        let iconRect = NSRect(x: 0, y: Constants.UI.statusBarIconYOffset, width: size.width, height: size.height)
        baseImage.draw(in: iconRect)
        
        // 2. Draw the scanning dot if needed
        if showDot {
            let dotSize = Constants.UI.scanningIndicatorSize
            let dotOffset = Constants.UI.scanningIndicatorOffset
            
            let dotRect = NSRect(
                x: size.width - dotSize - dotOffset,
                y: size.height - dotSize - dotOffset,
                width: dotSize,
                height: dotSize
            )
            
            // In a template, opacity determines what gets tinted.
            // We want the dot to be solid color.
            let dotPath = NSBezierPath(ovalIn: dotRect)
            NSColor.black.setFill() 
            dotPath.fill()
        }
        
        image.unlockFocus()
        
        // Setting isTemplate = true is the standard macOS way.
        // It makes the icon White in Dark Mode and Black in Light Mode.
        image.isTemplate = true 
        
        return image
    }
    
    @objc func handleStatusBarClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showStatusBarMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    @objc func showStatusBarMenu() {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: NSLocalizedString("Open Kits", comment: ""), action: #selector(togglePopoverFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        let settingsItem = NSMenuItem(title: NSLocalizedString("Settings", comment: ""), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusBarItem.menu = menu
        statusBarItem.button?.performClick(nil)
        statusBarItem.menu = nil
    }
    
    @objc func showSettings() {
        if settingsPopover == nil {
            let popover = NSPopover()
            popover.contentSize = NSSize(width: Constants.UI.settingsPopoverWidth, height: Constants.UI.settingsPopoverHeight)
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: SettingsView(settings: settings, launchAtLoginHelper: launchAtLoginHelper)
                    .environment(\.uiScale, CGFloat(settings.uiScale))
            )
            self.settingsPopover = popover
        }
        
        if let button = statusBarItem.button {
            settingsPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Focus the popover's window so it receives keyboard events (like Escape)
            if let window = settingsPopover?.contentViewController?.view.window {
                window.makeKey()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        launchAtLoginHelper.isEnabled.toggle()
    }
    
    @objc func togglePopoverFromMenu() {
        if let button = statusBarItem.button {
            togglePopover(button)
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                // Trigger quick refresh of first N repos before showing
                // By the time animation completes, they'll have fresh data
                gitScanner.refreshFirstNRepositories(count: Constants.Scanning.quickRefreshCount)
                
                popover.contentSize = NSSize(width: CGFloat(settings.popoverWidth), height: CGFloat(settings.popoverHeight))
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

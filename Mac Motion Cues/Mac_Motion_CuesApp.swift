import AppKit
import Combine
import Sparkle
import SwiftUI

@main
struct MacMotionCuesApp: App {
    // Use StateObject for view models that should persist
    var dotsViewModel = DotsViewModel.shared
    var motionViewModel = MotionViewModel.shared
    private let updaterController: SPUStandardUpdaterController
    // App-wide settings
    @AppStorage("appEnabled") private var appEnabled: Bool = true
    
    init() {
        // If you want to start the updater manually, pass false to startingUpdater and call .startUpdater() later
        // This is where you can also pass an updater delegate if you need one
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        // Only show the window when app is enabled
        WindowGroup {
            if appEnabled && motionViewModel.isMotionEnabled {
                DotsView(dotsViewModel: dotsViewModel, motionViewModel: motionViewModel)
                    .background(TransparentWindow())
            } else {
                // Empty view when disabled
                VStack {}
                    .background(TransparentWindow())
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
        
        // Enhanced menu bar with more options
        MenuBarExtra("Motion Cues", systemImage: "cursorarrow.motionlines.click") {
            MenuBar(dotsViewModel: dotsViewModel, motionViewModel: motionViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

class TransparentWindowView: NSView {
    override func viewDidMoveToWindow() {
        guard let window = window else { return }
        
        // Configure window properties
        window.backgroundColor = .clear
        window.isOpaque = false
        
        // Use .floating to stay above standard windows but below full-screen apps
        window.level = .floating
        
        // Critical: Make the entire window completely click-through
        window.ignoresMouseEvents = true
        
        // Ensure no interaction with window
        window.isMovableByWindowBackground = false
        window.hasShadow = false
        
        // Hide title bar elements
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.borderless)
        
        // Hide standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Make it screen size
        if let mainScreen = NSScreen.main {
            window.setFrame(mainScreen.frame, display: true)
        }
        
        super.viewDidMoveToWindow()
    }
    
    // No need for hit testing since we're ignoring all mouse events
}

// Fix the typo in the struct name
struct TransparentWindow: NSViewRepresentable {
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeNSView(context: Self.Context) -> NSView { return TransparentWindowView() }
}

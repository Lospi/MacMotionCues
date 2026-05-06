import AppKit
import Sparkle
import SwiftUI

@main
struct MacMotionCuesApp: App {
    private let motionViewModel = MotionViewModel.shared
    private let appState = AppState.shared
    private let overlay = OverlayWindowController()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Defer to the next runloop tick so NSApp is fully up before we
        // touch the headphone motion manager or create overlay windows.
        DispatchQueue.main.async { [motionViewModel, overlay, appState] in
            motionViewModel.bootstrap()
            overlay.startObservingMountConditions(
                appState: appState,
                motionViewModel: motionViewModel
            )
        }
    }

    var body: some Scene {
        MenuBarExtra("Motion Cues", systemImage: "cursorarrow.motionlines.click") {
            MenuBar(
                motionViewModel: motionViewModel,
                appState: appState,
                settings: DotsSettings.shared
            )
        }
        .menuBarExtraStyle(.window)

        Settings { EmptyView() }
    }
}

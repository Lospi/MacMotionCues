import AppKit
import Sparkle
import SwiftUI

@main
struct MacMotionCuesApp: App {
    private let pipeline = MotionPipeline.shared
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
        DispatchQueue.main.async { [pipeline, overlay, appState] in
            pipeline.bootstrap()
            overlay.startObservingMountConditions(
                appState: appState,
                pipeline: pipeline
            )
        }
    }

    var body: some Scene {
        MenuBarExtra("Motion Cues", systemImage: "cursorarrow.motionlines.click") {
            MenuBar(
                pipeline: pipeline,
                appState: appState,
                settings: DotsSettings.shared,
                updater: updaterController.updater
            )
        }
        .menuBarExtraStyle(.window)

        Settings { EmptyView() }
    }
}

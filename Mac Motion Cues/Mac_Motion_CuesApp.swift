import AppKit
import Sparkle
import SwiftUI

@main
struct MacMotionCuesApp: App {
    var motionViewModel = MotionViewModel.shared
    private let updaterController: SPUStandardUpdaterController
    @State private var overlay = OverlayWindowController()
    @AppStorage("appEnabled") private var appEnabled: Bool = true

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        MenuBarExtra("Motion Cues", systemImage: "cursorarrow.motionlines.click") {
            MenuBar(
                motionViewModel: motionViewModel,
                settings: DotsSettings.shared,
                overlay: overlay
            )
            .task { syncOverlay() }
            .onChange(of: appEnabled) { syncOverlay() }
            .onChange(of: motionViewModel.isMotionEnabled) { syncOverlay() }
        }
        .menuBarExtraStyle(.window)

        Settings { EmptyView() }
    }

    private func syncOverlay() {
        if appEnabled && motionViewModel.isMotionEnabled {
            overlay.install()
        } else {
            overlay.uninstall()
            // If the user disabled visual cues while motion was running,
            // stop the motion manager too so AirPods aren't read for nothing.
            if !appEnabled && motionViewModel.isMotionEnabled {
                motionViewModel.stopDeviceMotion()
            }
        }
    }
}

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
                settings: DotsSettings.shared
            )
            .task { syncOverlayMounting() }
            .onChange(of: appEnabled) { _, newValue in
                if !newValue && motionViewModel.isMotionEnabled {
                    motionViewModel.stopDeviceMotion()
                }
                syncOverlayMounting()
            }
            .onChange(of: motionViewModel.isMotionEnabled) { syncOverlayMounting() }
        }
        .menuBarExtraStyle(.window)

        Settings { EmptyView() }
    }

    private func syncOverlayMounting() {
        if appEnabled && motionViewModel.isMotionEnabled {
            overlay.install()
        } else {
            overlay.uninstall()
        }
    }
}

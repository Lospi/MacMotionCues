import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private struct Entry {
        let window: NSWindow
        let viewModel: DotsViewModel
    }

    private var entries: [CGDirectDisplayID: Entry] = [:]
    private var observer: NSObjectProtocol?
    private(set) var isInstalled = false

    func install() {
        guard !isInstalled else { return }
        isInstalled = true
        sync()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
    }

    func uninstall() {
        guard isInstalled else { return }
        isInstalled = false
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        let windowsToClose = Array(entries.values)
        entries.removeAll()
        for entry in windowsToClose {
            entry.window.orderOut(nil)
            entry.window.close()
        }
    }

    private func sync() {
        var current: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let id = screen.displayID {
                current[id] = screen
            }
        }

        let staleIDs = entries.keys.filter { current[$0] == nil }
        for id in staleIDs {
            if let entry = entries.removeValue(forKey: id) {
                entry.window.orderOut(nil)
                entry.window.close()
            }
        }

        for (id, screen) in current {
            if let entry = entries[id] {
                if entry.window.frame != screen.frame {
                    entry.window.setFrame(screen.frame, display: true)
                }
            } else {
                entries[id] = makeEntry(for: screen)
            }
        }
    }

    private func makeEntry(for screen: NSScreen) -> Entry {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        window.hasShadow = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let viewModel = DotsViewModel()
        let host = NSHostingView(
            rootView: DotsView(
                dotsViewModel: viewModel,
                motionViewModel: MotionViewModel.shared
            )
        )
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        window.orderFrontRegardless()

        return Entry(window: window, viewModel: viewModel)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

import AppKit
import CoreMotion
import Foundation

enum MotionState: Equatable {
    case permissionNotDetermined
    case permissionDenied
    case noAirPods
    case connecting
    case streaming
    case stale
}

@Observable
final class MotionViewModel: NSObject, CMHeadphoneMotionManagerDelegate {
    static let shared = MotionViewModel()

    var state: MotionState = .permissionNotDetermined
    var motionX: Double = 0.0
    var motionY: Double = 0.0

    var isStreaming: Bool { state == .streaming }

    private let motion = CMHeadphoneMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "MotionQueue"
        q.qualityOfService = .userInteractive
        return q
    }()

    private var staleTimer: Timer?
    private let staleThreshold: TimeInterval = 5.0

    override init() {
        super.init()
        motion.delegate = self
    }

    func bootstrap() {
        applyAuthorizationStatus()
    }

    func requestPermission() {
        // First call to startDeviceMotionUpdates triggers the OS prompt when
        // status is .notDetermined. The sample handler resolves the next
        // state once the user accepts/denies.
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] sample, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.handleStreamCallback(sample: sample, error: error)
            }
        }
    }

    static func openSystemSettings() {
        let primary = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion")!
        if NSWorkspace.shared.open(primary) { return }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(fallback)
        }
    }

    // MARK: - State transitions

    private func applyAuthorizationStatus() {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .notDetermined:
            transition(to: .permissionNotDetermined)
        case .denied, .restricted:
            transition(to: .permissionDenied)
        case .authorized:
            motion.startConnectionStatusUpdates()
            startSampleStream()
            // `.connecting` is reserved for the delegate `didConnect` event
            // (i.e. the brief gap between AirPods physically connecting and
            // the first sample arriving). Default to `.noAirPods` here and
            // let real signals; delegate callbacks or sample arrivals;
            // drive forward transitions. Don't clobber an active state if
            // bootstrap re-runs (e.g. when the menu is reopened).
            switch state {
            case .permissionNotDetermined, .permissionDenied:
                transition(to: .noAirPods)
            default:
                break
            }
        @unknown default:
            transition(to: .permissionDenied)
        }
    }

    private func handleStreamCallback(sample: CMDeviceMotion?, error: Error?) {
        let status = CMHeadphoneMotionManager.authorizationStatus()
        if status == .denied || status == .restricted {
            motion.stopDeviceMotionUpdates()
            transition(to: .permissionDenied)
            return
        }
        if status == .notDetermined {
            return
        }
        // Authorized from here on.
        motion.startConnectionStatusUpdates()
        if let sample {
            ingestSample(sample)
        } else if error != nil {
            // No sample yet; assume AirPods aren't actively streaming.
            // Delegate `didConnect` or a future sample will promote us forward.
            if state == .permissionNotDetermined || state == .permissionDenied {
                transition(to: .noAirPods)
            }
        }
    }

    private func startSampleStream() {
        guard !motion.isDeviceMotionActive else { return }
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] sample, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let sample {
                    self.ingestSample(sample)
                } else if let error {
                    print("Motion error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func ingestSample(_ sample: CMDeviceMotion) {
        // Flip state BEFORE writing motion values so observers see .streaming
        // before any consumer reads the new motion data; preserves the
        // "isMotionEnabled before first paint" ordering invariant.
        if state != .streaming {
            transition(to: .streaming)
        }
        motionX = sample.userAcceleration.x
        motionY = sample.userAcceleration.y
        resetStaleTimer()
    }

    private func transition(to next: MotionState) {
        guard state != next else { return }
        state = next
        if next != .streaming {
            cancelStaleTimer()
        }
        if next == .noAirPods || next == .permissionDenied || next == .permissionNotDetermined {
            motionX = 0
            motionY = 0
        }
    }

    // MARK: - Stale watchdog

    private func resetStaleTimer() {
        staleTimer?.invalidate()
        staleTimer = Timer.scheduledTimer(withTimeInterval: staleThreshold, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.state == .streaming {
                self.transition(to: .stale)
            }
        }
    }

    private func cancelStaleTimer() {
        staleTimer?.invalidate()
        staleTimer = nil
    }

    // MARK: - CMHeadphoneMotionManagerDelegate

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard CMHeadphoneMotionManager.authorizationStatus() == .authorized else { return }
            if self.state == .noAirPods {
                self.transition(to: .connecting)
                self.startSampleStream()
            }
        }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.motion.stopDeviceMotionUpdates()
            if CMHeadphoneMotionManager.authorizationStatus() == .authorized {
                self.transition(to: .noAirPods)
            }
        }
    }
}

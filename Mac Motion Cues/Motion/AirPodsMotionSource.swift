import AppKit
import CoreMotion
import Foundation
import Observation

@Observable
final class AirPodsMotionSource: NSObject, MotionSource, CMHeadphoneMotionManagerDelegate {
    static let id = "airpods"
    static let displayName = "AirPods"
    static let hardwareAvailability = HardwareAvailability.airpods
    static let defaultPriority = 100

    static let shared = AirPodsMotionSource()

    private(set) var state: MotionSourceState = .permissionNotDetermined
    private(set) var latestSample: VehicleMotionSample?

    private let motion = CMHeadphoneMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "AirPodsMotionQueue"
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

    func teardown() {
        motion.stopDeviceMotionUpdates()
        cancelStaleTimer()
        if state == .streaming || state == .connecting || state == .stale {
            transition(to: .idle)
        }
    }

    func requestPermission() {
        // First call to startDeviceMotionUpdates triggers the OS prompt when
        // status is .notDetermined. The handler resolves the next state.
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] sample, error in
            DispatchQueue.main.async {
                self?.handleStreamCallback(sample: sample, error: error)
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
            // `.connecting` is reserved for the delegate `didConnect` event.
            // Default to `.idle` (authorized but no AirPods) here and let real
            // signals; delegate callbacks or sample arrivals; drive forward
            // transitions. Don't clobber an active state if bootstrap re-runs.
            switch state {
            case .permissionNotDetermined, .permissionDenied, .unavailable:
                transition(to: .idle)
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
        motion.startConnectionStatusUpdates()
        if let sample {
            ingestSample(sample)
        } else if error != nil {
            if state == .permissionNotDetermined || state == .permissionDenied {
                transition(to: .idle)
            }
        }
    }

    private func startSampleStream() {
        guard !motion.isDeviceMotionActive else { return }
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] sample, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let sample {
                    self.ingestSample(sample)
                } else if let error {
                    print("AirPods motion error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func ingestSample(_ sample: CMDeviceMotion) {
        // Flip state BEFORE writing the sample so observers see `.streaming`
        // before any consumer reads `latestSample`; preserves the
        // "active source streaming before first paint" invariant.
        if state != .streaming {
            transition(to: .streaming)
        }
        latestSample = VehicleMotionSample(
            lateralAccel: sample.userAcceleration.x,
            longitudinalAccel: sample.userAcceleration.y,
            // rotationRate.z is the head's yaw angular velocity (rad/s);
            // a direct signal for sustained turning, vs. integrating noisy
            // lateral accel.
            yawRate: sample.rotationRate.z,
            confidence: 1.0,
            timestamp: sample.timestamp
        )
        resetStaleTimer()
    }

    private func transition(to next: MotionSourceState) {
        guard state != next else { return }
        state = next
        if next != .streaming {
            cancelStaleTimer()
        }
        switch next {
        case .idle, .permissionDenied, .permissionNotDetermined, .unavailable:
            latestSample = nil
        default:
            break
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
            if self.state == .idle {
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
                self.transition(to: .idle)
            }
        }
    }
}

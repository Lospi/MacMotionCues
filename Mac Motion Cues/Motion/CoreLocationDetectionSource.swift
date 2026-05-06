import AppKit
import CoreLocation
import Foundation
import Observation

@Observable
final class CoreLocationDetectionSource: NSObject, VehicleDetectionSource, CLLocationManagerDelegate {
    static let id = "corelocation"
    static let displayName = "Location services"
    static let hardwareAvailability = HardwareAvailability.locationServices

    static let shared = CoreLocationDetectionSource()

    private(set) var state: MotionSourceState = .permissionNotDetermined
    private(set) var inVehicle: Bool = false

    /// Speed (m/s) at which we start counting toward "in vehicle". ~18 km/h.
    private let entrySpeedThreshold: Double = 5.0
    /// Speed (m/s) below which we start counting toward "stationary". ~3.6 km/h.
    private let exitSpeedThreshold: Double = 1.0
    private let entryHoldTime: TimeInterval = 5.0
    private let exitHoldTime: TimeInterval = 30.0

    private let manager: CLLocationManager
    private var aboveEntrySince: Date?
    private var belowExitSince: Date?
    private var isActive: Bool = false

    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10
    }

    /// Called when the user enables this source. Triggers the OS prompt the
    /// first time (status `.notDetermined`); on subsequent calls just resumes
    /// updates if already authorized.
    func bootstrap() {
        isActive = true
        if manager.authorizationStatus == .notDetermined {
            transition(to: .permissionNotDetermined)
            manager.requestWhenInUseAuthorization()
        } else {
            applyAuthorizationStatus()
        }
    }

    func teardown() {
        isActive = false
        manager.stopUpdatingLocation()
        inVehicle = false
        aboveEntrySince = nil
        belowExitSince = nil
        if state == .streaming || state == .connecting {
            transition(to: .idle)
        }
    }

    static func openSystemSettings() {
        let primary = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
        if NSWorkspace.shared.open(primary) { return }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(fallback)
        }
    }

    // MARK: - State transitions

    /// Observes the current authorization status; never triggers a prompt.
    /// The `isActive` flag gates whether we actually start streaming when
    /// authorized; important because the delegate's didChangeAuthorization
    /// callback fires once on init, before the user has enabled this source.
    private func applyAuthorizationStatus() {
        switch manager.authorizationStatus {
        case .notDetermined:
            transition(to: .permissionNotDetermined)
        case .denied, .restricted:
            transition(to: .permissionDenied)
            manager.stopUpdatingLocation()
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            if isActive {
                transition(to: .streaming)
                manager.startUpdatingLocation()
            } else {
                transition(to: .idle)
            }
        @unknown default:
            transition(to: .permissionDenied)
        }
    }

    private func transition(to next: MotionSourceState) {
        guard state != next else { return }
        state = next
        if next != .streaming {
            inVehicle = false
            aboveEntrySince = nil
            belowExitSince = nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.applyAuthorizationStatus()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let latest = locations.last else { return }
            self.processLocation(latest)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures (no GPS yet, etc.) are common; ignore.
    }

    private func processLocation(_ location: CLLocation) {
        let speed = max(0, location.speed)        // CLLocation.speed is -1 when invalid
        let now = location.timestamp

        if speed >= entrySpeedThreshold {
            if aboveEntrySince == nil { aboveEntrySince = now }
            belowExitSince = nil
            if !inVehicle, let since = aboveEntrySince, now.timeIntervalSince(since) >= entryHoldTime {
                inVehicle = true
            }
        } else if speed <= exitSpeedThreshold {
            if belowExitSince == nil { belowExitSince = now }
            aboveEntrySince = nil
            if inVehicle, let since = belowExitSince, now.timeIntervalSince(since) >= exitHoldTime {
                inVehicle = false
            }
        }
        // Between thresholds: keep current state, don't reset hold timers.
    }
}

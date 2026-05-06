import Foundation
import Observation

/// A normalized motion sample produced by a `MotionSource`. Frame conventions
/// are source-specific (head frame for AirPods, device frame for an on-board
/// IMU, etc.); each source is responsible for any conversion before emitting.
struct VehicleMotionSample: Equatable {
    let lateralAccel: Double
    let longitudinalAccel: Double
    let yawRate: Double           // rad/s, signed
    let confidence: Double        // 0...1, source-reported (kept for future fusion)
    let timestamp: TimeInterval
}

enum MotionSourceState: Equatable {
    case unavailable(reason: String)
    case permissionNotDetermined
    case permissionDenied
    case idle                      // permission/hardware OK, not yet streaming
    case connecting
    case streaming
    case stale
    case error(String)
}

enum HardwareAvailability {
    case airpods
    case locationServices
    case appleSiliconLaptop        // reserved for a future MacBookIMUMotionSource
}

/// Drives the dot motion. One active `MotionSource` at a time wins by priority.
protocol MotionSource: AnyObject, Identifiable, Observable {
    static var id: String { get }
    static var displayName: String { get }
    static var hardwareAvailability: HardwareAvailability { get }
    static var defaultPriority: Int { get }

    var state: MotionSourceState { get }
    var latestSample: VehicleMotionSample? { get }

    func bootstrap()
    func teardown()
}

extension MotionSource {
    var id: String { Self.id }
}

/// Gates whether cues should render based on whether the user appears to be
/// in a vehicle. Independent of motion drive; multiple detection sources can
/// be enabled, and any one returning `inVehicle == true` opens the gate.
protocol VehicleDetectionSource: AnyObject, Identifiable, Observable {
    static var id: String { get }
    static var displayName: String { get }
    static var hardwareAvailability: HardwareAvailability { get }

    var state: MotionSourceState { get }
    var inVehicle: Bool { get }

    func bootstrap()
    func teardown()
}

extension VehicleDetectionSource {
    var id: String { Self.id }
}

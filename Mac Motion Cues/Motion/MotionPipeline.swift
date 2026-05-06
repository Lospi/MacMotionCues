import Foundation
import Observation

@Observable
final class MotionPipeline {
    static let shared = MotionPipeline()

    let motionSources: [any MotionSource]
    let detectionSources: [any VehicleDetectionSource]

    var enabledMotionSourceIDs: Set<String> {
        didSet { defaults.set(Array(enabledMotionSourceIDs), forKey: Keys.motionSources) }
    }
    var enabledDetectionSourceIDs: Set<String> {
        didSet { defaults.set(Array(enabledDetectionSourceIDs), forKey: Keys.detectionSources) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let motionSources = "enabledMotionSourceIDs"
        static let detectionSources = "enabledDetectionSourceIDs"
    }

    private init() {
        self.motionSources = [AirPodsMotionSource.shared]
        self.detectionSources = [CoreLocationDetectionSource.shared]

        defaults.register(defaults: [
            Keys.motionSources: [AirPodsMotionSource.id],
            Keys.detectionSources: [String](),    // off by default; user opts in
        ])
        self.enabledMotionSourceIDs = Set(defaults.stringArray(forKey: Keys.motionSources) ?? [])
        self.enabledDetectionSourceIDs = Set(defaults.stringArray(forKey: Keys.detectionSources) ?? [])
    }

    /// Highest-priority enabled source that is `.streaming`; falls back to
    /// highest-priority enabled source so the UI still has a state to render
    /// even when nothing is streaming.
    var activeMotionSource: (any MotionSource)? {
        let enabled = motionSources.filter { enabledMotionSourceIDs.contains($0.id) }
        let streaming = enabled.filter { $0.state == .streaming }
        return streaming.max(by: { Self.priority($0) < Self.priority($1) })
            ?? enabled.max(by: { Self.priority($0) < Self.priority($1) })
    }

    var latestSample: VehicleMotionSample? { activeMotionSource?.latestSample }

    var isStreaming: Bool { activeMotionSource?.state == .streaming }

    func shouldRenderCues(appEnabled: Bool) -> Bool {
        guard appEnabled else { return false }
        guard isStreaming else { return false }
        let activeDetections = detectionSources.filter { enabledDetectionSourceIDs.contains($0.id) }
        if activeDetections.isEmpty { return true }
        return activeDetections.contains { $0.inVehicle }
    }

    func bootstrap() {
        for src in motionSources where enabledMotionSourceIDs.contains(src.id) {
            src.bootstrap()
        }
        for src in detectionSources where enabledDetectionSourceIDs.contains(src.id) {
            src.bootstrap()
        }
    }

    func setMotionSource(_ id: String, enabled: Bool) {
        guard let src = motionSources.first(where: { $0.id == id }) else { return }
        if enabled {
            enabledMotionSourceIDs.insert(id)
            src.bootstrap()
        } else {
            enabledMotionSourceIDs.remove(id)
            src.teardown()
        }
    }

    func setDetectionSource(_ id: String, enabled: Bool) {
        guard let src = detectionSources.first(where: { $0.id == id }) else { return }
        if enabled {
            enabledDetectionSourceIDs.insert(id)
            src.bootstrap()
        } else {
            enabledDetectionSourceIDs.remove(id)
            src.teardown()
        }
    }

    private static func priority(_ src: any MotionSource) -> Int {
        type(of: src).defaultPriority
    }
}

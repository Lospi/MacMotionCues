import Foundation
import SwiftUI

enum DotStyle: String, CaseIterable {
    case solid
    case dynamic
}

enum HaloStyle: String, CaseIterable {
    case off
    case solid
    case dynamic
}

@Observable
final class DotsSettings {
    static let shared = DotsSettings()

    var dotSize: CGFloat            { didSet { defaults.set(Double(dotSize), forKey: Keys.dotSize) } }
    var verticalSpacing: CGFloat    { didSet { defaults.set(Double(verticalSpacing), forKey: Keys.verticalSpacing) } }
    var motionSensitivity: CGFloat  { didSet { defaults.set(Double(motionSensitivity), forKey: Keys.motionSensitivity) } }
    var xMotionEnabled: Bool        { didSet { defaults.set(xMotionEnabled, forKey: Keys.xMotionEnabled) } }
    var dotStyle: DotStyle          { didSet { defaults.set(dotStyle.rawValue, forKey: Keys.dotStyle) } }
    var haloStyle: HaloStyle        { didSet { defaults.set(haloStyle.rawValue, forKey: Keys.haloStyle) } }

    let leftBound: CGFloat = -300
    let rightBound: CGFloat = 300

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let dotSize = "dotSize"
        static let verticalSpacing = "verticalSpacing"
        static let motionSensitivity = "motionSensitivity"
        static let xMotionEnabled = "xMotionEnabled"
        static let dotStyle = "dotStyle"
        static let haloStyle = "haloStyle"
    }

    private init() {
        defaults.register(defaults: [
            Keys.dotSize: 30.0,
            Keys.verticalSpacing: 50.0,
            Keys.motionSensitivity: 10.0,
            Keys.xMotionEnabled: false,
            Keys.dotStyle: DotStyle.dynamic.rawValue,
            Keys.haloStyle: HaloStyle.dynamic.rawValue,
        ])
        dotSize = CGFloat(defaults.double(forKey: Keys.dotSize))
        verticalSpacing = CGFloat(defaults.double(forKey: Keys.verticalSpacing))
        motionSensitivity = CGFloat(defaults.double(forKey: Keys.motionSensitivity))
        xMotionEnabled = defaults.bool(forKey: Keys.xMotionEnabled)
        dotStyle = DotStyle(rawValue: defaults.string(forKey: Keys.dotStyle) ?? "") ?? .dynamic
        haloStyle = HaloStyle(rawValue: defaults.string(forKey: Keys.haloStyle) ?? "") ?? .dynamic
    }

    func ensureSpacingFitsSize() {
        if verticalSpacing < dotSize * 1.5 {
            verticalSpacing = dotSize * 1.5
        }
    }
}

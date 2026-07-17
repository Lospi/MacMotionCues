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

/// Mirrors the color options of Apple's system "Vehicle Motion Cues"
/// accessibility feature (System Settings > Accessibility > Motion).
/// `.grayscale` keeps the existing black dot appearance.
enum DotColorOption: String, CaseIterable, Identifiable {
    case grayscale
    case blue
    case green
    case yellow
    case orange
    case red
    case purple

    var id: String { rawValue }

    /// `nil` for grayscale, which renders as plain black/vibrant with no tint.
    var tint: Color? {
        switch self {
        case .grayscale: return nil
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        }
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .grayscale: return "Grayscale"
        case .blue: return "Blue"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .red: return "Red"
        case .purple: return "Purple"
        }
    }
}

@Observable
final class DotsSettings {
    static let shared = DotsSettings()

    var dotSize: CGFloat {
        didSet {
            defaults.set(Double(dotSize), forKey: Keys.dotSize)
            if verticalSpacing < dotSize * 1.5 {
                verticalSpacing = dotSize * 1.5
            }
        }
    }
    var verticalSpacing: CGFloat    { didSet { defaults.set(Double(verticalSpacing), forKey: Keys.verticalSpacing) } }
    var motionSensitivity: CGFloat  { didSet { defaults.set(Double(motionSensitivity), forKey: Keys.motionSensitivity) } }
    var bubbleThreshold: CGFloat     { didSet { defaults.set(Double(bubbleThreshold), forKey: Keys.bubbleThreshold) } }
    var xMotionEnabled: Bool        { didSet { defaults.set(xMotionEnabled, forKey: Keys.xMotionEnabled) } }
    var dotStyle: DotStyle          { didSet { defaults.set(dotStyle.rawValue, forKey: Keys.dotStyle) } }
    var haloStyle: HaloStyle        { didSet { defaults.set(haloStyle.rawValue, forKey: Keys.haloStyle) } }
    var dotColor: DotColorOption    { didSet { defaults.set(dotColor.rawValue, forKey: Keys.dotColor) } }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let dotSize = "dotSize"
        static let verticalSpacing = "verticalSpacing"
        static let motionSensitivity = "motionSensitivity"
        static let bubbleThreshold = "bubbleThreshold"
        static let xMotionEnabled = "xMotionEnabled"
        static let dotStyle = "dotStyle"
        static let haloStyle = "haloStyle"
        static let dotColor = "dotColor"
    }

    private init() {
        defaults.register(defaults: [
            Keys.dotSize: 30.0,
            Keys.verticalSpacing: 50.0,
            Keys.motionSensitivity: 10.0,
            Keys.bubbleThreshold: 0.035,
            Keys.xMotionEnabled: false,
            Keys.dotStyle: DotStyle.dynamic.rawValue,
            Keys.haloStyle: HaloStyle.off.rawValue,
            Keys.dotColor: DotColorOption.grayscale.rawValue,
        ])
        dotSize = CGFloat(defaults.double(forKey: Keys.dotSize))
        verticalSpacing = CGFloat(defaults.double(forKey: Keys.verticalSpacing))
        motionSensitivity = CGFloat(defaults.double(forKey: Keys.motionSensitivity))
        bubbleThreshold = CGFloat(defaults.double(forKey: Keys.bubbleThreshold))
        xMotionEnabled = defaults.bool(forKey: Keys.xMotionEnabled)
        dotStyle = DotStyle(rawValue: defaults.string(forKey: Keys.dotStyle) ?? "") ?? .dynamic
        haloStyle = HaloStyle(rawValue: defaults.string(forKey: Keys.haloStyle) ?? "") ?? .off
        dotColor = DotColorOption(rawValue: defaults.string(forKey: Keys.dotColor) ?? "") ?? .grayscale
    }

}

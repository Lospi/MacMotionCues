import AppKit
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

/// Dot or halo tint. `.automatic` keeps the untinted black / vibrant look.
/// Components are sRGB, quantized to 8 bits so they round-trip through the
/// persisted `#RRGGBB` string without drifting.
enum DotTint: Equatable {
    case automatic
    case custom(red: Double, green: Double, blue: Double)

    init(rgb: UInt32) {
        self = .custom(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// Returns nil for colors that can't be expressed in sRGB (e.g. patterns).
    init?(nsColor: NSColor) {
        guard let srgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        func byte(_ component: CGFloat) -> UInt32 {
            UInt32((max(0, min(1, component)) * 255).rounded())
        }
        self.init(rgb: byte(srgb.redComponent) << 16 | byte(srgb.greenComponent) << 8 | byte(srgb.blueComponent))
    }

    /// "automatic" or "#RRGGBB"; anything unparseable falls back to `.automatic`.
    init(storageValue: String) {
        let hex = storageValue.dropFirst()
        guard storageValue.hasPrefix("#"), hex.count == 6, hex.allSatisfy(\.isHexDigit),
              let rgb = UInt32(hex, radix: 16) else {
            self = .automatic
            return
        }
        self.init(rgb: rgb)
    }

    var storageValue: String {
        guard case let .custom(red, green, blue) = self else { return "automatic" }
        let rgb = [red, green, blue].map { Int(($0 * 255).rounded()) }
        return String(format: "#%02X%02X%02X", rgb[0], rgb[1], rgb[2])
    }

    var color: Color? {
        guard case let .custom(red, green, blue) = self else { return nil }
        return Color(.sRGB, red: red, green: green, blue: blue)
    }

    var nsColor: NSColor? {
        guard case let .custom(red, green, blue) = self else { return nil }
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
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
    var xMotionEnabled: Bool        { didSet { defaults.set(xMotionEnabled, forKey: Keys.xMotionEnabled) } }
    var dotStyle: DotStyle          { didSet { defaults.set(dotStyle.rawValue, forKey: Keys.dotStyle) } }
    var haloStyle: HaloStyle        { didSet { defaults.set(haloStyle.rawValue, forKey: Keys.haloStyle) } }
    var dotTint: DotTint {
        didSet {
            // The color panel fires per drag event; skip no-op writes so they don't invalidate the overlay.
            guard dotTint != oldValue else { return }
            defaults.set(dotTint.storageValue, forKey: Keys.dotTint)
            dotTintColor = dotTint.color
        }
    }
    var haloTint: DotTint {
        didSet {
            guard haloTint != oldValue else { return }
            defaults.set(haloTint.storageValue, forKey: Keys.haloTint)
            haloTintColor = haloTint.color
        }
    }
    var dotOpacity: Double          { didSet { defaults.set(dotOpacity, forKey: Keys.dotOpacity) } }
    var haloOpacity: Double         { didSet { defaults.set(haloOpacity, forKey: Keys.haloOpacity) } }

    /// Resolved once per tint change so the overlay never converts per frame. nil = automatic.
    private(set) var dotTintColor: Color?
    private(set) var haloTintColor: Color?

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
        static let dotTint = "dotTint"
        static let dotOpacity = "dotOpacity"
        static let haloTint = "haloTint"
        static let haloOpacity = "haloOpacity"
    }

    private init() {
        defaults.register(defaults: [
            Keys.dotSize: 30.0,
            Keys.verticalSpacing: 50.0,
            Keys.motionSensitivity: 10.0,
            Keys.xMotionEnabled: false,
            Keys.dotStyle: DotStyle.dynamic.rawValue,
            Keys.haloStyle: HaloStyle.dynamic.rawValue,
            Keys.dotTint: DotTint.automatic.storageValue,
            Keys.dotOpacity: 1.0,
            Keys.haloTint: DotTint.automatic.storageValue,
            Keys.haloOpacity: 1.0,
        ])
        dotSize = CGFloat(defaults.double(forKey: Keys.dotSize))
        verticalSpacing = CGFloat(defaults.double(forKey: Keys.verticalSpacing))
        motionSensitivity = CGFloat(defaults.double(forKey: Keys.motionSensitivity))
        xMotionEnabled = defaults.bool(forKey: Keys.xMotionEnabled)
        dotStyle = DotStyle(rawValue: defaults.string(forKey: Keys.dotStyle) ?? "") ?? .dynamic
        haloStyle = HaloStyle(rawValue: defaults.string(forKey: Keys.haloStyle) ?? "") ?? .dynamic
        let dotTint = DotTint(storageValue: defaults.string(forKey: Keys.dotTint) ?? "")
        self.dotTint = dotTint
        dotTintColor = dotTint.color
        let haloTint = DotTint(storageValue: defaults.string(forKey: Keys.haloTint) ?? "")
        self.haloTint = haloTint
        haloTintColor = haloTint.color
        // Floor keeps cues from vanishing entirely (e.g. a hand-edited default).
        dotOpacity = min(1, max(0.2, defaults.double(forKey: Keys.dotOpacity)))
        haloOpacity = min(1, max(0.2, defaults.double(forKey: Keys.haloOpacity)))
    }

}

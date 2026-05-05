import Foundation
import SwiftUI

@Observable
final class DotsSettings {
    static let shared = DotsSettings()

    var dotSize: CGFloat = 30
    var verticalSpacing: CGFloat = 50
    var motionSensitivity: CGFloat = 10.0
    var xMotionEnabled: Bool = false

    let leftBound: CGFloat = -300
    let rightBound: CGFloat = 300

    private init() {}

    func ensureSpacingFitsSize() {
        if verticalSpacing < dotSize * 1.5 {
            verticalSpacing = dotSize * 1.5
        }
    }
}

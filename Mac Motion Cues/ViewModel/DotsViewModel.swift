import Foundation
import SwiftUI

@Observable
class DotsViewModel {
    var dots: [Dot] = []
    var dotSize: CGFloat = 30
    var verticalSpacing: CGFloat = 50
    var speedY: CGFloat = 0.5
    var speedX: CGFloat = 0.5
    var motionSensitivity: CGFloat = 10.0
    var xMotionEnabled: Bool = false

    let leftBound: CGFloat = -300
    let rightBound: CGFloat = 300

    static let shared = DotsViewModel()

    private var screenHeight: CGFloat = 200
    private var screenWidth: CGFloat = 800

    private var lastUpdateTime: TimeInterval = CACurrentMediaTime()

    init() {}

    func updateXMotionEnabled(_ enabled: Bool) {
        xMotionEnabled = enabled
    }

    func initializeDots(screenHeight: CGFloat, screenWidth: CGFloat = 800) {
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth

        let positions = stride(from: 0, through: screenHeight, by: verticalSpacing)

        var newDots: [Dot] = []

        for (index, y) in positions.enumerated() {
            let dot = Dot(
                offsetY: screenHeight - y,
                offsetX: index % 2 == 0 ? 100 : screenWidth - 100,
                size: dotSize
            )
            newDots.append(dot)
        }

        dots = newDots
    }

    func updateDotSize() {
        if verticalSpacing < dotSize * 1.5 {
            verticalSpacing = dotSize * 1.5
        }
        updateSpacing()
    }

    func updateSpacing() {
        let positions = Array(stride(from: 0, through: screenHeight, by: verticalSpacing))
        let targetCount = positions.count

        // Reuse existing dots (preserving identity) and adjust count as needed
        while dots.count > targetCount {
            dots.removeLast()
        }
        while dots.count < targetCount {
            dots.append(Dot(offsetY: 0, offsetX: 0, size: dotSize))
        }

        for (i, y) in positions.enumerated() {
            dots[i].offsetY = screenHeight - y
            dots[i].size = dotSize
        }
    }

    func updateDotsPosition() {
        guard MotionViewModel.shared.isMotionEnabled else { return }

        let fixedDeltaTime: CGFloat = 1.0 / 60.0

        let motionX = CGFloat(MotionViewModel.shared.motionX)
        let motionY = CGFloat(MotionViewModel.shared.motionY)

        let isXMotionRelevant = abs(motionX) > 0.02
        let isYMotionRelevant = abs(motionY) > 0.02

        var baseSpeedY: CGFloat = 0
        var xInfluence: CGFloat = 0

        if isYMotionRelevant {
            baseSpeedY = 200 * fixedDeltaTime * motionY * motionSensitivity
        }

        if isXMotionRelevant, xMotionEnabled {
            xInfluence = 200 * fixedDeltaTime * motionX * motionSensitivity
        }

        let boundWidth = rightBound - leftBound

        // Pre-compute min/max Y once before the loop instead of per-wrapping-dot
        var maxY = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        for dot in dots {
            if dot.offsetY > maxY { maxY = dot.offsetY }
            if dot.offsetY < minY { minY = dot.offsetY }
        }

        for index in dots.indices {
            if isXMotionRelevant {
                dots[index].offsetX += xInfluence

                if dots[index].offsetX < leftBound {
                    dots[index].offsetX = rightBound - (leftBound - dots[index].offsetX).truncatingRemainder(dividingBy: boundWidth)
                } else if dots[index].offsetX > rightBound {
                    dots[index].offsetX = leftBound + (dots[index].offsetX - rightBound).truncatingRemainder(dividingBy: boundWidth)
                }
            }

            if isYMotionRelevant {
                dots[index].offsetY -= baseSpeedY

                if dots[index].offsetY <= -dotSize {
                    dots[index].offsetY = maxY + verticalSpacing
                } else if dots[index].offsetY > screenHeight + verticalSpacing {
                    dots[index].offsetY = minY - verticalSpacing
                }
            }
        }
    }
}

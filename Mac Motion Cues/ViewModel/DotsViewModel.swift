import Foundation
import SwiftUI

@Observable
class DotsViewModel {
    var dots: [Dot] = []

    private var screenHeight: CGFloat = 200
    private var lastUpdateTime: TimeInterval = CACurrentMediaTime()

    init() {
        observeSpacingSettings()
    }

    private func observeSpacingSettings() {
        withObservationTracking {
            _ = DotsSettings.shared.verticalSpacing
            _ = DotsSettings.shared.dotSize
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateSpacing()
                self?.observeSpacingSettings()
            }
        }
    }

    func initializeDots(screenHeight: CGFloat) {
        self.screenHeight = screenHeight

        let settings = DotsSettings.shared
        let positions = balancedPositions(screenHeight: screenHeight, spacing: settings.verticalSpacing)

        var newDots: [Dot] = []
        for y in positions {
            newDots.append(Dot(
                offsetY: screenHeight - y,
                offsetX: 0,
                size: settings.dotSize
            ))
        }
        dots = newDots
    }

    func updateSpacing() {
        let settings = DotsSettings.shared
        let positions = balancedPositions(screenHeight: screenHeight, spacing: settings.verticalSpacing)
        let targetCount = positions.count

        // Reuse existing dots (preserving identity) and adjust count as needed
        while dots.count > targetCount {
            dots.removeLast()
        }
        while dots.count < targetCount {
            dots.append(Dot(offsetY: 0, offsetX: 0, size: settings.dotSize))
        }

        for (i, y) in positions.enumerated() {
            dots[i].offsetY = screenHeight - y
            dots[i].size = settings.dotSize
        }
    }

    // Produces an even number of Y stops so the left/right column counts
    // (derived from `index % 2` in DotsView) always match.
    private func balancedPositions(screenHeight: CGFloat, spacing: CGFloat) -> [CGFloat] {
        var positions = Array(stride(from: 0, through: screenHeight, by: spacing))
        if positions.count % 2 != 0 { positions.removeLast() }
        return positions
    }

    func updateDotsPosition() {
        guard MotionViewModel.shared.isStreaming else { return }

        let settings = DotsSettings.shared
        let fixedDeltaTime: CGFloat = 1.0 / 60.0

        let motionX = CGFloat(MotionViewModel.shared.motionX)
        let motionY = CGFloat(MotionViewModel.shared.motionY)

        let isXMotionRelevant = abs(motionX) > 0.02
        let isYMotionRelevant = abs(motionY) > 0.02

        if !isXMotionRelevant && !isYMotionRelevant { return }

        let baseSpeedY: CGFloat = isYMotionRelevant
            ? 200 * fixedDeltaTime * motionY * settings.motionSensitivity
            : 0
        let xInfluence: CGFloat = (isXMotionRelevant && settings.xMotionEnabled)
            ? 200 * fixedDeltaTime * motionX * settings.motionSensitivity
            : 0

        let leftBound = settings.leftBound
        let rightBound = settings.rightBound
        let boundWidth = rightBound - leftBound

        // Pass 1: apply per-frame motion (no wraps yet — wrap targets must
        // see consistent post-move state across all dots).
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
            }
        }

        guard isYMotionRelevant else { return }

        // Pass 2: measure post-move column extents.
        var maxY = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        for dot in dots {
            if dot.offsetY > maxY { maxY = dot.offsetY }
            if dot.offsetY < minY { minY = dot.offsetY }
        }

        // Pass 3: wrap dots that crossed bounds. Update running max/min so
        // multiple wraps in the same frame land at consecutive positions
        // instead of stacking at the same Y.
        let dotSize = settings.dotSize
        let spacing = settings.verticalSpacing
        let topBound = screenHeight + spacing

        for index in dots.indices {
            if dots[index].offsetY <= -dotSize {
                let newY = maxY + spacing
                dots[index].offsetY = newY
                maxY = newY
            } else if dots[index].offsetY > topBound {
                let newY = minY - spacing
                dots[index].offsetY = newY
                minY = newY
            }
        }
    }
}

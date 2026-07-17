import Foundation
import SwiftUI

@Observable
class DotsViewModel {
    var dots: [Dot] = []
    var bubbles: [MotionBubble] = []

    private var screenHeight: CGFloat = 200
    private var screenWidth: CGFloat = 300
    private var lastUpdateTime: TimeInterval = CACurrentMediaTime()
    private var smoothedMotionX: CGFloat = 0
    private var smoothedMotionY: CGFloat = 0
    private var smoothedYawRate: CGFloat = 0
    private var bubbleSpawnAccumulator: CGFloat = 0

    private let motionDeadZone: CGFloat = 0.02
    private let inputResponseTime: CGFloat = 0.18
    private let maximumFrameDelta: CGFloat = 1.0 / 15.0
    private let maximumCueOffset: CGFloat = 42
    private let radialCueOffset: CGFloat = 20
    private let yawCueOffset: CGFloat = 18
    private let springResponse: CGFloat = 28
    private let springDamping: CGFloat = 10
    private let maximumBubbleCount = 120

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

    func initializeDots(screenHeight: CGFloat, screenWidth: CGFloat) {
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth

        dots = makeAnchoredDots(settings: DotsSettings.shared)
        bubbles.removeAll()
        resetMotionSmoothing()
    }

    func updateScreenSize(width: CGFloat, height: CGFloat) {
        screenWidth = width
        screenHeight = height
        dots = makeAnchoredDots(settings: DotsSettings.shared)
    }

    func updateSpacing() {
        dots = makeAnchoredDots(settings: DotsSettings.shared)
    }

    func updateDotsPosition(screenWidth: CGFloat) {
        self.screenWidth = screenWidth

        let now = CACurrentMediaTime()
        let deltaTime = min(maximumFrameDelta, max(0, CGFloat(now - lastUpdateTime)))
        lastUpdateTime = now

        guard let sample = MotionPipeline.shared.latestSample,
              MotionPipeline.shared.isStreaming else {
            bubbles.removeAll()
            resetMotionSmoothing()
            return
        }

        let settings = DotsSettings.shared

        let targetMotionX = deadZoned(CGFloat(sample.lateralAccel))
        let targetMotionY = deadZoned(CGFloat(sample.longitudinalAccel))
        let targetYawRate = CGFloat(sample.yawRate)
        let smoothing = interpolationFactor(deltaTime: deltaTime, responseTime: inputResponseTime)

        smoothedMotionX += (targetMotionX - smoothedMotionX) * smoothing
        smoothedMotionY += (targetMotionY - smoothedMotionY) * smoothing
        smoothedYawRate += (targetYawRate - smoothedYawRate) * smoothing

        let motionMagnitude = hypot(smoothedMotionX, smoothedMotionY) + min(abs(smoothedYawRate) * 0.08, 0.12)
        let normalizedMotion = min(max((motionMagnitude - settings.bubbleThreshold) / 0.25, 0), 1)

        updateBubbles(deltaTime: deltaTime)
        spawnBubblesIfNeeded(
            deltaTime: deltaTime,
            normalizedMotion: normalizedMotion,
            directionX: settings.xMotionEnabled ? smoothedMotionX : 0,
            directionY: smoothedMotionY,
            settings: settings
        )

        for index in dots.indices {
            let target = targetOffset(for: dots[index], settings: settings)
            applySpring(to: index, targetX: target.x, targetY: target.y, deltaTime: deltaTime)
        }
    }

    private func resetMotionSmoothing() {
        lastUpdateTime = CACurrentMediaTime()
        smoothedMotionX = 0
        smoothedMotionY = 0
        smoothedYawRate = 0
        bubbleSpawnAccumulator = 0
    }

    private func deadZoned(_ value: CGFloat) -> CGFloat {
        abs(value) > motionDeadZone ? value : 0
    }

    private func interpolationFactor(deltaTime: CGFloat, responseTime: CGFloat) -> CGFloat {
        guard responseTime > 0 else { return 1 }
        return 1 - CGFloat(exp(-Double(deltaTime / responseTime)))
    }

    private func makeAnchoredDots(settings: DotsSettings) -> [Dot] {
        let margin = max(settings.dotSize * 2, 72)
        let horizontalSpacing = max(settings.verticalSpacing * 1.8, 96)
        let verticalSpacing = max(settings.verticalSpacing * 1.25, 72)
        var anchors: [(x: CGFloat, y: CGFloat)] = []

        for y in steppedPositions(from: margin, through: screenHeight - margin, spacing: verticalSpacing) {
            anchors.append((margin, y))
            anchors.append((screenWidth - margin, y))
        }

        for x in steppedPositions(from: margin + horizontalSpacing, through: screenWidth - margin - horizontalSpacing, spacing: horizontalSpacing) {
            anchors.append((x, margin))
            anchors.append((x, screenHeight - margin))
        }

        return anchors.map { anchor in
            Dot(anchorX: anchor.x, anchorY: anchor.y, offsetY: 0, size: settings.dotSize)
        }
    }

    private func steppedPositions(from start: CGFloat, through end: CGFloat, spacing: CGFloat) -> [CGFloat] {
        guard end >= start else { return [(start + end) / 2] }

        var values: [CGFloat] = []
        var value = start
        while value <= end {
            values.append(value)
            value += spacing
        }
        return values
    }

    private func targetOffset(for dot: Dot, settings: DotsSettings) -> (x: CGFloat, y: CGFloat) {
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        let relativeX = dot.anchorX - centerX
        let relativeY = dot.anchorY - centerY
        let distance = max(hypot(relativeX, relativeY), 1)
        let radialX = relativeX / distance
        let radialY = relativeY / distance
        let tangentX = -radialY
        let tangentY = radialX
        let sensitivity = settings.motionSensitivity / 10

        let lateralX = settings.xMotionEnabled ? smoothedMotionX * maximumCueOffset * sensitivity : 0
        let radialAmount = smoothedMotionY * radialCueOffset * sensitivity
        let yawAmount = smoothedYawRate * yawCueOffset

        let targetX = lateralX + radialX * radialAmount + tangentX * yawAmount
        let targetY = radialY * radialAmount + tangentY * yawAmount

        return (
            min(max(targetX, -maximumCueOffset), maximumCueOffset),
            min(max(targetY, -maximumCueOffset), maximumCueOffset)
        )
    }

    private func applySpring(to index: Int, targetX: CGFloat, targetY: CGFloat, deltaTime: CGFloat) {
        let xDisplacement = targetX - dots[index].offsetX
        let yDisplacement = targetY - dots[index].offsetY

        dots[index].velocityX += (xDisplacement * springResponse - dots[index].velocityX * springDamping) * deltaTime
        dots[index].velocityY += (yDisplacement * springResponse - dots[index].velocityY * springDamping) * deltaTime
        dots[index].offsetX += dots[index].velocityX * deltaTime
        dots[index].offsetY += dots[index].velocityY * deltaTime
    }

    private func updateBubbles(deltaTime: CGFloat) {
        for index in bubbles.indices {
            bubbles[index].age += deltaTime
            bubbles[index].x += bubbles[index].velocityX * deltaTime
            bubbles[index].y += bubbles[index].velocityY * deltaTime
            bubbles[index].velocityX *= 0.985
            bubbles[index].velocityY *= 0.985
        }

        bubbles.removeAll { bubble in
            bubble.age >= bubble.lifetime
                || bubble.x < -80
                || bubble.x > screenWidth + 80
                || bubble.y < -80
                || bubble.y > screenHeight + 80
        }
    }

    private func spawnBubblesIfNeeded(
        deltaTime: CGFloat,
        normalizedMotion: CGFloat,
        directionX: CGFloat,
        directionY: CGFloat,
        settings: DotsSettings
    ) {
        guard normalizedMotion > 0, !dots.isEmpty else { return }

        let spawnRate = 10 + normalizedMotion * 50
        bubbleSpawnAccumulator += deltaTime * spawnRate

        var spawnCount = min(Int(bubbleSpawnAccumulator), 5)
        bubbleSpawnAccumulator -= CGFloat(spawnCount)

        while spawnCount > 0, bubbles.count < maximumBubbleCount {
            spawnBubble(
                normalizedMotion: normalizedMotion,
                directionX: directionX,
                directionY: directionY,
                settings: settings
            )
            spawnCount -= 1
        }
    }

    private func spawnBubble(
        normalizedMotion: CGFloat,
        directionX: CGFloat,
        directionY: CGFloat,
        settings: DotsSettings
    ) {
        let dotIndex = dots.indices.randomElement() ?? 0
        let dot = dots[dotIndex]
        let startX = dot.anchorX + dot.offsetX + CGFloat.random(in: -18...18)
        let startY = dot.anchorY + dot.offsetY + CGFloat.random(in: -settings.verticalSpacing * 0.35...settings.verticalSpacing * 0.35)

        let length = max(hypot(directionX, directionY), 0.0001)
        let unitX = directionX / length
        let unitY = directionY / length
        let perpendicularX = -unitY
        let perpendicularY = unitX
        let speed = CGFloat.random(in: 55...170) * (0.65 + normalizedMotion)
        // Keep scatter proportional to speed so the perpendicular jitter never
        // dominates the main-direction component (max ~31° off-axis), instead
        // of an independent random range that could swing wildly off-axis.
        let maxScatterRatio: CGFloat = 0.6
        let scatter = speed * CGFloat.random(in: -maxScatterRatio...maxScatterRatio)
        let maximumSize = settings.dotSize * 0.7
        let minimumSize = max(4, maximumSize * 0.5)
        let size = CGFloat.random(in: minimumSize...maximumSize)

        bubbles.append(MotionBubble(
            x: startX,
            y: startY,
            size: size,
            maximumSize: maximumSize,
            lifetime: CGFloat.random(in: 1.0...2.0),
            velocityX: unitX * speed + perpendicularX * scatter,
            velocityY: unitY * speed + perpendicularY * scatter,
            growth: CGFloat.random(in: 0...max(0, maximumSize - size))
        ))
    }

}

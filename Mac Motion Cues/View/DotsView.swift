import AppKit
import SwiftUI

struct DotsView: View {
    @Bindable var dotsViewModel: DotsViewModel
    @Bindable var pipeline: MotionPipeline

    private let haloLineWidth: CGFloat = 1.5
    private let haloGap: CGFloat = 1.0

    private func edgeFadeOpacity(y: CGFloat, height: CGFloat, fadeRange: CGFloat, inset: CGFloat) -> Double {
        guard fadeRange > 0 else { return 1 }
        let topRamp = max(0, min(1, (y - inset) / fadeRange))
        let bottomRamp = max(0, min(1, (height - inset - y) / fadeRange))
        return Double(min(topRamp, bottomRamp))
    }

    var body: some View {
        let settings = DotsSettings.shared
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !pipeline.isStreaming)) { context in
                ZStack {
                    ForEach(dotsViewModel.bubbles) { bubble in
                        CueMark(style: settings.dotStyle, color: settings.dotColor, opacity: settings.dotStyle == .solid ? 0.35 : 1)
                        .frame(width: bubble.renderedSize, height: bubble.renderedSize)
                        .position(x: bubble.x, y: bubble.y)
                        .opacity(bubble.opacity * edgeFadeOpacity(
                            y: bubble.y,
                            height: geometry.size.height,
                            fadeRange: bubble.renderedSize * 2,
                            inset: bubble.renderedSize
                        ))
                    }

                    ForEach(dotsViewModel.dots.indices, id: \.self) { index in
                        let dot = dotsViewModel.dots[index]
                        ZStack {
                            CueMark(style: settings.dotStyle, color: settings.dotColor)
                            .padding(settings.haloStyle != .off ? haloLineWidth + haloGap : 0)

                            if settings.haloStyle == .solid {
                                Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: haloLineWidth)
                            }
                            if settings.haloStyle == .dynamic {
                                VibrantRing(lineWidth: haloLineWidth)
                            }
                        }
                        .frame(width: dot.size, height: dot.size)
                        .position(
                            x: dot.anchorX + dot.offsetX,
                            y: dot.anchorY + dot.offsetY
                        )
                        .opacity(edgeFadeOpacity(y: dot.anchorY + dot.offsetY, height: geometry.size.height, fadeRange: dot.size * 2, inset: dot.size))
                    }
                }
                .onChange(of: context.date) {
                    dotsViewModel.updateDotsPosition(screenWidth: geometry.size.width)
                }
                .onAppear {
                    dotsViewModel.initializeDots(screenHeight: geometry.size.height, screenWidth: geometry.size.width)
                }
                .onChange(of: geometry.size.height) {
                    dotsViewModel.initializeDots(screenHeight: geometry.size.height, screenWidth: geometry.size.width)
                }
                .onChange(of: geometry.size.width) {
                    dotsViewModel.updateScreenSize(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
}

/// Renders a single cue mark (dot or bubble): a flat fill for `.solid`, or a
/// vibrant blur tinted with `color` (skipped for `.grayscale`) for `.dynamic`.
///
/// A faint stroke + shadow is always applied (independent of the optional
/// `HaloStyle` ring) so the mark keeps a visible edge against backgrounds
/// close to its own tone, rather than relying solely on vibrancy.
struct CueMark: View {
    let style: DotStyle
    let color: DotColorOption
    var opacity: Double = 1

    var body: some View {
        Group {
            if style == .solid {
                Circle().fill((color.tint ?? .black).opacity(opacity))
            } else {
                VibrantCircle()
                    .overlay {
                        if let tint = color.tint {
                            Circle().fill(tint.opacity(0.5 * opacity))
                        }
                    }
            }
        }
    }
}

final class CircularEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.width / 2
    }
}

struct VibrantCircle: NSViewRepresentable {
    func makeNSView(context: Context) -> CircularEffectView {
        let view = CircularEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: CircularEffectView, context: Context) {}
}

final class RingEffectView: NSVisualEffectView {
    var lineWidth: CGFloat = 1.5 {
        didSet { needsLayout = true }
    }

    override func layout() {
        super.layout()
        if bounds.width > 0, bounds.height > 0 {
            maskImage = Self.annulusMask(size: bounds.size, lineWidth: lineWidth)
        }
    }

    private static func annulusMask(size: NSSize, lineWidth: CGFloat) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let path = NSBezierPath(ovalIn: rect)
            path.append(NSBezierPath(ovalIn: rect.insetBy(dx: lineWidth, dy: lineWidth)))
            path.windingRule = .evenOdd
            path.fill()
            return true
        }
    }
}

struct VibrantRing: NSViewRepresentable {
    let lineWidth: CGFloat

    func makeNSView(context: Context) -> RingEffectView {
        let view = RingEffectView()
        view.blendingMode = .behindWindow
        view.material = .menu
        view.state = .active
        view.wantsLayer = true
        view.lineWidth = lineWidth
        return view
    }

    func updateNSView(_ nsView: RingEffectView, context: Context) {
        nsView.lineWidth = lineWidth
    }
}

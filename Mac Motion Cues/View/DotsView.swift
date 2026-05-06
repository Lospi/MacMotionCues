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
                    ForEach(dotsViewModel.dots.indices, id: \.self) { index in
                        let dot = dotsViewModel.dots[index]
                        ZStack {
                            Group {
                                if settings.dotStyle == .solid {
                                    Circle().fill(.black)
                                } else {
                                    VibrantCircle()
                                }
                            }
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
                            x: index % 2 == 0
                                ? 150 + dot.offsetX
                                : geometry.size.width - 150 + dot.offsetX,
                            y: dot.offsetY
                        )
                        .opacity(edgeFadeOpacity(y: dot.offsetY, height: geometry.size.height, fadeRange: dot.size * 2, inset: dot.size))
                    }
                }
                .onChange(of: context.date) {
                    dotsViewModel.updateDotsPosition()
                }
                .onAppear {
                    dotsViewModel.initializeDots(screenHeight: geometry.size.height)
                }
                .onChange(of: geometry.size.height) {
                    dotsViewModel.initializeDots(screenHeight: geometry.size.height)
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

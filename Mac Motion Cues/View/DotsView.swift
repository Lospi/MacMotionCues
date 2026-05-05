import AppKit
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

struct DotsView: View {
    @Bindable var dotsViewModel: DotsViewModel
    @Bindable var motionViewModel: MotionViewModel
    @AppStorage("dotStyle") private var dotStyle: DotStyle = .dynamic
    @AppStorage("haloStyle") private var haloStyle: HaloStyle = .dynamic

    private let haloLineWidth: CGFloat = 1.5
    private let haloGap: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !motionViewModel.isMotionEnabled)) { context in
                ZStack {
                    ForEach(dotsViewModel.dots.indices, id: \.self) { index in
                        let dot = dotsViewModel.dots[index]
                        ZStack {
                            Group {
                                if dotStyle == .solid {
                                    Circle().fill(.black)
                                } else {
                                    VibrantCircle()
                                }
                            }
                            .padding(haloStyle != .off ? haloLineWidth + haloGap : 0)

                            if haloStyle == .solid {
                                Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: haloLineWidth)
                            }
                            if haloStyle == .dynamic {
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
                        .opacity(dot.offsetY < dotsViewModel.dotSize ||
                            dot.offsetY > geometry.size.height - 150 ? 0 : 1)
                    }
                }
                .onChange(of: context.date) {
                    dotsViewModel.updateDotsPosition()
                }
                .onAppear {
                    dotsViewModel.initializeDots(screenHeight: geometry.size.height)
                }
                .onDisappear {
                    motionViewModel.stopDeviceMotion()
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

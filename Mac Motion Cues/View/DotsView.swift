import Combine
import SwiftUI

struct DotsView: View {
    @Bindable var dotsViewModel: DotsViewModel
    @Bindable var motionViewModel: MotionViewModel

    @State private var scrollingCancellable: AnyCancellable?

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !motionViewModel.isMotionEnabled)) { context in
                ZStack {
                    ForEach(Array(dotsViewModel.dots.enumerated()), id: \.element.id) { index, dot in
                        Circle()
                            .fill(.black)
                            .frame(width: dot.size, height: dot.size)
                            .position(
                                x: index % 2 == 0
                                    ? 150 + dot.offsetX
                                    : geometry.size.width - 150 + dot.offsetX,
                                y: dot.offsetY
                            )
                            .opacity(dot.offsetY < dotsViewModel.dotSize ||
                                dot.offsetY > geometry.size.height - 150 ? 0 : 1)
                            .animation(.easeInOut(duration: 0.06), value: dot.offsetY)
                            .animation(.easeInOut(duration: 0.06), value: dot.offsetX)
                    }
                }
                .onChange(of: context.date) {
                    dotsViewModel.updateDotsPosition()
                }
                .onAppear {
                    dotsViewModel.initializeDots(screenHeight: geometry.size.height)
                }
                .onDisappear {
                    scrollingCancellable?.cancel()
                }
            }
        }
    }
}

//
//  Dot.swift
//  Mac Motion Cues
//
//  Created by Roberto Camargo on 14/03/25.
//

import SwiftUI

struct Dot: Identifiable {
    var id = UUID()
    var anchorX: CGFloat
    var anchorY: CGFloat
    var offsetX: CGFloat = 0
    var offsetY: CGFloat
    var velocityX: CGFloat = 0
    var velocityY: CGFloat = 0
    var size: CGFloat
}

struct MotionBubble: Identifiable {
    var id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var maximumSize: CGFloat
    var age: CGFloat = 0
    var lifetime: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var growth: CGFloat

    var progress: CGFloat {
        min(max(age / lifetime, 0), 1)
    }

    var renderedSize: CGFloat {
        min(size + growth * progress, maximumSize)
    }

    var opacity: Double {
        Double((1 - progress) * 1)
    }
}

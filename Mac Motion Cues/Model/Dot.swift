//
//  Dot.swift
//  Mac Motion Cues
//
//  Created by Roberto Camargo on 14/03/25.
//

import SwiftUI

struct Dot: Identifiable, Animatable {
    var id = UUID()
    var offsetY: CGFloat
    var offsetX: CGFloat = 0
    var size: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offsetX, offsetY) }
        set {
            offsetX = newValue.first
            offsetY = newValue.second
        }
    }
}

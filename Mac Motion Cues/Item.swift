//
//  Item.swift
//  Mac Motion Cues
//
//  Created by Roberto Camargo on 21/11/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

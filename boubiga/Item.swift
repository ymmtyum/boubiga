//
//  Item.swift
//  boubiga
//
//  Created by 山本勇磨 on 2026/05/17.
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

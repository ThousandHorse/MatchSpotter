//
//  Item.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

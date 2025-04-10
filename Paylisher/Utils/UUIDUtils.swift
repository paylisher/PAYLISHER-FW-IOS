//
//  UUIDUtils.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation

public extension UUID {
    static func v7() -> Self {
        TimeBasedEpochGenerator.shared.v7()
    }
}

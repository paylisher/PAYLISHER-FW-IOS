//
//  Date+Util.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

import Foundation

extension Date {
    func toMillis() -> Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }
}

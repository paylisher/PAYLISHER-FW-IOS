//
//  String+Util.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

import Foundation

extension String {
    func mask() -> String {
        String(repeating: "*", count: count)
    }
}

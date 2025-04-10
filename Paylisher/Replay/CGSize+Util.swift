//
//  CGSize+Util.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

#if os(iOS)
    import Foundation

    extension CGSize {
        func hasSize() -> Bool {
            if width == 0 || height == 0 {
                return false
            }
            return true
        }
    }
#endif

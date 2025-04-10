//
//  UIColor+Util.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

#if os(iOS)

    import Foundation
    import UIKit

    extension UIColor {
        func toRGBString() -> String? {
            cgColor.toRGBString()
        }
    }
#endif

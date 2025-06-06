//
//  CGColor+Util.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

#if os(iOS)

    import Foundation
    import UIKit

    extension CGColor {
        func toRGBString() -> String? {
            guard let components = components, components.count >= 3 else {
                return nil
            }

            let red = Int(components[0] * 255)
            let green = Int(components[1] * 255)
            let blue = Int(components[2] * 255)

            return String(format: "#%02X%02X%02X", red, green, blue)
        }
    }
#endif

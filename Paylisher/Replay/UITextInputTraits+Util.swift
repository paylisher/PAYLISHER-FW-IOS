//
//  UITextInputTraits+Util.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

#if os(iOS)
    import Foundation
    import UIKit

    private let sensibleTypes: [UITextContentType] = [
        .newPassword, .oneTimeCode, .creditCardNumber,
        .telephoneNumber, .emailAddress, .password,
        .username, .URL, .name, .nickname,
        .middleName, .familyName, .nameSuffix,
        .namePrefix, .organizationName, .location,
        .fullStreetAddress, .streetAddressLine1,
        .streetAddressLine2, .addressCity, .addressState,
        .addressCityAndState, .postalCode,
    ]

    extension UITextInputTraits {
        func isSensitiveText() -> Bool {
            if isSecureTextEntry ?? false {
                return true
            }

            if let contentType = textContentType, let contentType = contentType {
                return sensibleTypes.contains(contentType)
            }

            return false
        }
    }
#endif

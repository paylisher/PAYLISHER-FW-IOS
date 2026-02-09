//
//  PaylisherSwiftUIViewModifiers.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

#if canImport(SwiftUI)
    import Foundation
    import SwiftUI

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    struct PaylisherSwiftUIViewModifier: ViewModifier {
        let viewEventName: String

        let screenEvent: Bool

        let properties: [String: Any]?

        func body(content: Content) -> some View {
            content.onAppear {
                if screenEvent {
                    PaylisherSDK.shared.screen(viewEventName, properties: properties)
                } else {
                    PaylisherSDK.shared.capture(viewEventName, properties: properties)
                }
            }
        }
    }

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public extension View {
        func paylisherScreenView(_ screenName: String? = nil,
                               _ properties: [String: Any]? = nil) -> some View
        {
            let viewEventName = screenName ?? "\(type(of: self))"
            return modifier(PaylisherSwiftUIViewModifier(viewEventName: viewEventName,
                                                       screenEvent: true,
                                                       properties: properties))
        }

        func paylisherViewSeen(_ event: String,
                             _ properties: [String: Any]? = nil) -> some View
        {
            modifier(PaylisherSwiftUIViewModifier(viewEventName: event,
                                                screenEvent: false,
                                                properties: properties))
        }
    }

#endif


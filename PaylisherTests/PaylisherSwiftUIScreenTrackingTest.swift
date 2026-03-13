//
//  PaylisherSwiftUIScreenTrackingTest.swift
//  PaylisherTests
//
//  Created by Codex on 13.03.26.
//

import Foundation
import Nimble
import Quick

#if os(iOS) || os(tvOS)
    import UIKit
    @testable import Paylisher

    class PaylisherSwiftUIScreenTrackingTest: QuickSpec {
        override func spec() {
            beforeEach {
                UIViewController.resetAutoScreenCaptureDedupeState()
            }

            afterEach {
                UIViewController.resetAutoScreenCaptureDedupeState()
            }

            it("returns nil for placeholder SwiftUI type Content") {
                let inferredName = UIViewController.extractSwiftUIViewName(
                    from: "UIHostingController<Content>"
                )

                expect(inferredName).to(beNil())
            }

            it("keeps View suffix for ContentView type") {
                let inferredName = UIViewController.extractSwiftUIViewName(
                    from: "UIHostingController<ContentView>"
                )

                expect(inferredName) == "ContentView"
            }

            it("extracts nested custom SwiftUI view name") {
                let inferredName = UIViewController.extractSwiftUIViewName(
                    from: "UIHostingController<ModifiedContent<CheckoutView, _TraitWritingModifier<Optional<LocalizedStringKey>>>>"
                )

                expect(inferredName) == "CheckoutView"
            }

            it("prefers explicit title over parsed SwiftUI type") {
                let viewController = UIViewController()
                viewController.title = "Checkout Screen"

                let name = UIViewController.getViewControllerName(
                    viewController,
                    className: "UIHostingController<Content>"
                )

                expect(name) == "Checkout Screen"
            }

            it("dedupes repeated auto screen names in a short interval") {
                let baseTime = Date(timeIntervalSince1970: 1000)

                let firstCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", at: baseTime)
                let duplicateCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", at: baseTime.addingTimeInterval(0.25))
                let captureAfterWindow = UIViewController.shouldCaptureAutoScreenView("ContentView", at: baseTime.addingTimeInterval(1.25))

                expect(firstCapture) == true
                expect(duplicateCapture) == false
                expect(captureAfterWindow) == true
            }
        }
    }
#endif

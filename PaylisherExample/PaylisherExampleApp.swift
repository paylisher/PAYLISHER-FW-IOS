//
//  PaylisherExampleApp.swift
//  PaylisherExample
//
//  Created by Rasim Burak Kaya on 9.04.2025.
//

import SwiftUI

@main
struct PaylisherExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .paylisherScreenView() // will infer the class name (ContentView)
        }
    }
}

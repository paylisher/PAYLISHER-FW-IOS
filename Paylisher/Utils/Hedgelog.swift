//
//  Hedgelog.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation

var hedgeLogEnabled = false

func toggleHedgeLog(_ enabled: Bool) {
    hedgeLogEnabled = enabled
}

// Meant for internally logging Paylisher related things
func hedgeLog(_ message: String) {
    if !hedgeLogEnabled { return }
    print("[Paylisher] \(message)")
}

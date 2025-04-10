//
//  Errors.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation

struct InternalPaylisherError: Error, CustomStringConvertible {
    let description: String

    init(description: String, fileID: StaticString = #fileID, line: UInt = #line) {
        self.description = "\(description) (\(fileID):\(line))"
    }
}

struct FatalPaylisherError: Error, CustomStringConvertible {
    let description: String

    init(description: String, fileID: StaticString = #fileID, line: UInt = #line) {
        self.description = "Fatal Paylisher error: \(description) (\(fileID):\(line))"
    }
}

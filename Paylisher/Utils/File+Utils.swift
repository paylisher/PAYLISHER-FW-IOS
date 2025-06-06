//
//  File+Utils.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation

public func deleteSafely(_ file: URL) {
    if FileManager.default.fileExists(atPath: file.path) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            hedgeLog("Error trying to delete file \(file.path) \(error)")
        }
    }
}

/// Check if provided directory exists
func directoryExists(_ directory: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) && isDirectory.boolValue
}

func createDirectoryAtURLIfNeeded(url: URL) {
    if FileManager.default.fileExists(atPath: url.path) { return }
    do {
        try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true)
    } catch {
        hedgeLog("Error creating storage directory: \(error)")
    }
}

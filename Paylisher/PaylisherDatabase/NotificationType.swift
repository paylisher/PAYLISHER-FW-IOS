//
//  NotificationType.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

public enum NotificationType {
    case push
    case actionBased
    case geofence
    case inApp
    
    
    init?(rawValue: String) {
        switch rawValue {
        case "IN-APP":
            self = .inApp
        case "PUSH":
            self = .push
        case "ACTION-BASED":
            self = .actionBased
        case "GEOFENCE":
            self = .geofence
        
        default:
            return nil
        }
    }
}

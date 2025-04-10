//
//  PaylisherConsumerPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation

struct PaylisherConsumerPayload {
    let events: [PaylisherEvent]
    let completion: (Bool) -> Void
}

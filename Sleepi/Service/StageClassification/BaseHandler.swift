//
//  Handler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation

protocol Handler{
    var next: Handler? { get }
    
    func handle(_ request: Request) async throws
}

class BaseHandler: Handler {
    var next: Handler?
    
    init(with handler: Handler? = nil) {
        self.next = handler
    }
    
    func handle(_ request: Request) async throws {
        try await next?.handle(request)
    }
}

//
//  Connection.swift
//  ControllerKit
//
//  Created by Robin Goos on 31/10/15.
//  Copyright © 2015 Robin Goos. All rights reserved.
//

import Foundation

protocol _ReadableChannel {
    func receive(data: NSData)
}

protocol _WritableChannel {}

protocol Channel {
    typealias MessageType
}

protocol ReadableChannel : Channel {
    var onReceive: ((MessageType) -> ())? { get set }
}

protocol WritableChannel : Channel {
    func send(message: MessageType)
}
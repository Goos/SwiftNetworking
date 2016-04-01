//
//  TCPSocket.swift
//  SwiftNetworking
//
//  Created by Robin Goos on 10/03/16.
//  Copyright © 2016 Robin Goos. All rights reserved.
//

import Foundation

public protocol Socket {
    func write<T: Marshallable>(data: T)
    func read<T: Marshallable>(read: (T) -> ())
}

public protocol NetworkStreamSocket : Socket {
    func connect(address: Address, success: (() -> ())?, error: ((ErrorType) -> ())?)
    func connect(address: NSData, success: (() -> ())?, error: ((ErrorType) -> ())?)
    func disconnect(completed: (() -> ())?)
    
    func listen(port: UInt16, interface: String?, connection: ((TCPSocket) -> ())?, error: ((ErrorType) -> ())?)
    func close()
}

public protocol NetworkDatagramSocket : Socket {
    func bind(address: Address)
    func bind(address: NSData)
    func unbind()
}

public final class TCPSocket : GCDAsyncSocketDelegate {
    private var socket: GCDAsyncSocket!
    private var state: SocketState = .Idle
    private(set) var connected: Bool = false
    
    public var onDisconnect: (() -> ())?
    private var onConnection: ((TCPSocket) -> ())?
    private var onConnected: (() -> ())?
    private var onError: ((ErrorType) -> ())?
    
    deinit {
        disconnect()
    }
    
    private init(socket: GCDAsyncSocket) {
        self.socket = socket
        self.state = .Connected
    }
    
    public init(socketQueue: dispatch_queue_t? = nil, callbackQueue: dispatch_queue_t? = nil) {
        let sQueue = socketQueue ?? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        let cQueue = socketQueue ?? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: cQueue, socketQueue: sQueue)
    }
    
    public func connect(address: Address, success: (() -> ())? = nil, error: ((ErrorType) -> ())? = nil) {
        guard state == .Idle else {
            error?(NSError(domain: "", code: 0, userInfo: nil))
            return 
        }
        
        self.onConnected = success
        self.onError = error
        
        if let interface = address.interface {
            do {
                try socket.connectToHost(address.host, onPort: address.port, viaInterface: interface, withTimeout: 30)
            } catch let err as NSError {
                error?(err)
            }
        } else {
            do {
                try socket.connectToHost(address.host, onPort: address.port, withTimeout: 30)
            } catch let err as NSError {
                error?(err)
            }
        }
    }
    
    public func connect(sockaddr: NSData, success: (() -> ())? = nil, error: ((ErrorType) -> ())? = nil) {
        guard state == .Idle else {
            error?(NSError(domain: "", code: 0, userInfo: nil))
            return 
        }
        
        self.onConnected = success
        self.onError = error
        
        do {
            try socket.connectToAddress(sockaddr)
        } catch let err as NSError {
            error?(err)
        }
    }
    
    public func disconnect(completed: (() -> ())? = nil) {
        if state == .Connected {
            socket.disconnect()
        }
    }
    
    public func listen(port: UInt16, interface: String? = nil, connection: ((TCPSocket) -> ())? = nil, error: ((ErrorType) -> ())? = nil) {
        guard state == .Idle else {
            error?(NSError(domain: "", code: 0, userInfo: nil))
            return
        }
        
        do {
            try socket.acceptOnInterface(interface, port: port)
        } catch let err as NSError {
            error?(err)
        }
    }
    
    public func close() {
        if state == .Listening {
            socket.disconnect()
        }
    }
    
    @objc public func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        onConnected?()
    }
    
    @objc public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        onDisconnect?()
    }
    
    @objc public func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        if let callback = onConnection {
            let socket = TCPSocket(socket: newSocket)
            callback(socket)
        }
    }
    
//    func bind(address: Address) {
//        
//    }
//    
//    func bind(sockaddr: NSData) {
//        
//    }
}

public enum SocketState {
    case Idle
    case Listening
    case Connected
    case Bound
}

public struct Address {
    var host: String
    var port: UInt16
    var interface: String?
}
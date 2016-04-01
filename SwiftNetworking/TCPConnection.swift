//
//  TCPConnection.swift
//  ControllerKit
//
//  Created by Robin Goos on 30/11/15.
//  Copyright © 2015 Robin Goos. All rights reserved.
//

import Foundation

public final class TCPConnection : NSObject, GCDAsyncSocketDelegate {
    private static let TCPHeaderTag = -1
    
    private(set) var socket: GCDAsyncSocket!
    private(set) var connected: Bool
    private var inputChannels: [UInt16:_ReadableChannel] = [:]
    private var outputChannels: [UInt16:_WritableChannel] = [:]
    private var currentHeader: TCPHeader? = nil
    
    var onSuccess: (() -> ())?
    var onError: ((NSError) -> ())?
    var onDisconnect: (() -> ())?
    
    convenience override init() {
        self.init(socketQueue: dispatch_queue_create("com.controllerkit.socket_queue", DISPATCH_QUEUE_CONCURRENT), delegateQueue: dispatch_queue_create("com.controllerkit.delegate_queue", DISPATCH_QUEUE_SERIAL))
    }
    
    public init(socketQueue: dispatch_queue_t, delegateQueue: dispatch_queue_t) {
        connected = false
        super.init()
        socket = GCDAsyncSocket(delegate: self, delegateQueue: delegateQueue, socketQueue: socketQueue)
    }
    
    public init(socket: GCDAsyncSocket, delegateQueue: dispatch_queue_t) {
        self.socket = socket
        connected = true
        super.init()
        socket.synchronouslySetDelegate(self, delegateQueue: delegateQueue)
        socket.readDataWithTimeout(-1, tag: TCPConnection.TCPHeaderTag)
    }
    
    public func connect(host: String, port: UInt16, success: (() -> ())?, error onError: ((NSError) -> ())?, disconnect onDisconnect: (() -> ())?) {
        if connected { return }
        
        self.onSuccess = success
        self.onError = onError
        self.onDisconnect = onDisconnect
        
        do {
            try socket.connectToHost(host, onPort: port)
        } catch let err as NSError {
            onError?(err)
        }
    }
    
    public func connect(address: NSData, success: (() -> ())?, error onError: ((NSError) -> ())?, disconnect onDisconnect: (() -> ())?) {
        if connected { return }
        
        self.onSuccess = success
        self.onError = onError
        self.onDisconnect = onDisconnect
        
        do {
            try socket.connectToAddress(address)
        } catch let err as NSError {
            onError?(err)
        }
    }
    
    public func disconnect() {
        socket.disconnect()
    }
    
    private func send(payload: NSData) {
        socket.writeData(payload, withTimeout: -1, tag: 0)
    }
    
    public func registerReadChannel<T: Marshallable>(identifier: UInt16, type: T.Type) -> TCPReadChannel<T> {
        let channel = TCPReadChannel<T>(identifier: identifier)
        inputChannels[identifier] = channel
        return channel
    }
    
    public func registerWriteChannel<T: Marshallable>(identifier: UInt16, type: T.Type) -> TCPWriteChannel<T> {
        let channel = TCPWriteChannel<T>(connection: self, identifier: identifier)
        outputChannels[identifier] = channel
        return channel
    }
    
    public func deregisterReadChannel<T: Marshallable>(channel: TCPReadChannel<T>) {
        inputChannels.removeValueForKey(channel.identifier)
    }
    
    public func deregisterWriteChannel<T: Marshallable>(channel: TCPWriteChannel<T>) {
        outputChannels.removeValueForKey(channel.identifier)
    }
    
    // MARK: GCDAsyncSocketDelegate
    public func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        socket.readDataToLength(UInt(TCPHeader.size), withTimeout: -1.0, tag: TCPConnection.TCPHeaderTag)
        onSuccess?()
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        onDisconnect?()
    }
    
    public func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        if tag == TCPConnection.TCPHeaderTag {
            guard let header = TCPHeader(data: data) else {
                return socket.readDataToLength(UInt(TCPHeader.size), withTimeout: -1.0, tag: TCPConnection.TCPHeaderTag)
            }
            socket.readDataToLength(UInt(header.length), withTimeout: -1.0, tag: Int(header.identifier))
        } else {
            if let channel = inputChannels[UInt16(tag)] {
                channel.receive(data)
            }
            
            socket.readDataToLength(UInt(TCPHeader.size), withTimeout: -1.0, tag: TCPConnection.TCPHeaderTag)
        }
    }
    
    public func enableBackgrounding() {
        socket.performBlock {
            self.socket.enableBackgroundingOnSocket()
        }
    }
}

struct TCPHeader : Marshallable {
    let identifier: UInt16
    let length: UInt32
    static var size: UInt32 {
        return UInt32(sizeof(UInt16) + sizeof(UInt32))
    }
    
    init(identifier: UInt16, length: UInt32) {
        self.identifier = identifier
        self.length = length
    }
    
    init?(data: NSData) {
        var buffer = ReadBuffer(data: data)
        guard let ident: UInt16 = buffer.read(),
            length: UInt32 = buffer.read() else {
            return nil
        }
        
        self.init(identifier: ident, length: length)
    }
    
    func marshal() -> NSData {
        var buffer = WriteBuffer()
        buffer << identifier
        buffer << length
        return buffer.data
    }
}

public final class TCPReadChannel<T: Marshallable> : _ReadableChannel {
    let identifier: UInt16
    var onReceive: ((T) -> ())?
    
    init(identifier: UInt16) {
        self.identifier = identifier
    }
    
    func receive(data: NSData) {
        if let payload = T(data: data) {
            onReceive?(payload)
        }
    }
    
    func receive(callback: (T) -> ()) {
        self.onReceive = callback
    }
}

public final class TCPWriteChannel<T: Marshallable> : _WritableChannel {
    let identifier: UInt16
    unowned let connection: TCPConnection
    
    init(connection: TCPConnection, identifier: UInt16) {
        self.identifier = identifier
        self.connection = connection
    }
    
    func send(payload: T) {
        let body = payload.marshal()
        let header = TCPHeader(identifier: identifier, length: UInt32(body.length))
        connection.send(header.marshal())
        connection.send(body)
    }
}

//
//  Marshalling.swift
//  ControllerKit
//
//  Created by Robin Goos on 30/11/15.
//  Copyright © 2015 Robin Goos. All rights reserved.
//

import Foundation

public protocol Marshallable {
    init?(data: NSData)
    func marshal() -> NSData
}

public protocol PrimitiveMarshallable {
    typealias SwappedType
    static var size: Int { get }
    
    init(swapped: SwappedType)
    init()
    
    func swapped() -> SwappedType
}

extension PrimitiveMarshallable {
    public static var size: Int {
        return sizeof(self)
    }
}

public struct WriteBuffer {
    var data: NSMutableData
    var length: Int {
        return data.length
    }
    
    init() {
        data = NSMutableData()
    }
    
    mutating func write<T: PrimitiveMarshallable where T.SwappedType : PrimitiveMarshallable>(value: T) {
        var swapped = value.swapped()
        let size = T.SwappedType.size
        data.appendBytes(&swapped, length: size)
    }
    
    mutating func write<T: Marshallable>(value: T) {
        let marshalled = value.marshal()
        data.appendData(marshalled)
    }
}

public struct ReadBuffer {
    var data: NSData
    var offset: Int = 0
    var length: Int {
        return data.length
    }
    
    init(data: NSData) {
        self.data = data
    }
    
    mutating func read<T: PrimitiveMarshallable where T.SwappedType : PrimitiveMarshallable>() -> T? {
        var value = T.SwappedType()
        let size = T.SwappedType.size
        if offset + size <= length {
            data.getBytes(&value, range: NSMakeRange(offset, size))
            offset += size
            return T(swapped: value)
        } else {
            return nil
        }
    }
    
    mutating func read<T: Marshallable>(length: Int? = nil) -> T? {
        let l = length ?? data.length - offset
        let remaining = data.subdataWithRange(NSMakeRange(offset, l))
        offset = data.length
        return T(data: remaining)
    }
}

prefix operator << {}
prefix func <<<T: PrimitiveMarshallable where T.SwappedType : PrimitiveMarshallable>(inout buffer: ReadBuffer) -> T? {
    return buffer.read()
}

prefix func <<<T: Marshallable>(inout buffer: ReadBuffer) -> T? {
    return buffer.read()
}

func <<<T: PrimitiveMarshallable where T.SwappedType : PrimitiveMarshallable>(inout buffer: WriteBuffer, value: T) {
    buffer.write(value)
}

func <<<T: Marshallable>(inout buffer: WriteBuffer, value: T) {
    buffer.write(value)
}

extension Int16 : PrimitiveMarshallable {
    public typealias SwappedType = UInt16
    
    public init(swapped: SwappedType) {
        let swapped = CFSwapInt16LittleToHost(swapped)
        self.init(bitPattern: swapped)
    }
    
    public func swapped() -> SwappedType {
        let unsigned = UInt16(bitPattern: self)
        return CFSwapInt16HostToBig(unsigned)
    }
}

extension Int32 : PrimitiveMarshallable {
    public typealias SwappedType = UInt32
    
    public init(swapped: SwappedType) {
        let swapped = CFSwapInt32LittleToHost(swapped)
        self.init(bitPattern: swapped)
    }
    
    public func swapped() -> SwappedType {
        let unsigned = UInt32(bitPattern: self)
        return CFSwapInt32HostToBig(unsigned)
    }
}

extension Int64 : PrimitiveMarshallable {
    public typealias SwappedType = UInt64
    
    public init(swapped: SwappedType) {
        let swapped = CFSwapInt64LittleToHost(swapped)
        self.init(bitPattern: swapped)
    }
    
    public func swapped() -> SwappedType {
        let unsigned = UInt64(bitPattern: self)
        return CFSwapInt64HostToBig(unsigned)
    }
}

extension UInt16 : PrimitiveMarshallable {
    public typealias SwappedType = UInt16
    
    public init(swapped: SwappedType) {
        self.init(CFSwapInt16LittleToHost(swapped))
    }
    
    public func swapped() -> SwappedType {
        return CFSwapInt16HostToBig(self)
    }
}

extension UInt32 : PrimitiveMarshallable {
    public typealias SwappedType = UInt32
    
    public init(swapped: SwappedType) {
        self.init(CFSwapInt32LittleToHost(swapped))
    }
    
    public func swapped() -> SwappedType {
        return CFSwapInt32HostToBig(self)
    }
}

extension UInt64 : PrimitiveMarshallable {
    public typealias SwappedType = UInt64
    
    public init(swapped: SwappedType) {
        self.init(CFSwapInt64LittleToHost(swapped))
    }
    
    public func swapped() -> SwappedType {
        return CFSwapInt64HostToBig(self)
    }
}

extension Float : PrimitiveMarshallable {
    public typealias SwappedType = CFSwappedFloat32
    
    public init(swapped: SwappedType) {
        self.init(CFConvertFloat32SwappedToHost(swapped))
    }
    
    public func swapped() -> SwappedType {
        return CFConvertFloat32HostToSwapped(self)
    }
}

extension Double : PrimitiveMarshallable {
    public typealias SwappedType = CFSwappedFloat64
    
    public init(swapped: SwappedType) {
        self.init(CFConvertFloat64SwappedToHost(swapped))
    }
    
    public func swapped() -> SwappedType {
        return CFConvertFloat64HostToSwapped(self)
    }
}

extension CFSwappedFloat32 : PrimitiveMarshallable {
    public typealias SwappedType = Float
    
    public init(swapped: SwappedType) {
        self.init(v: CFConvertFloat32HostToSwapped(swapped).v)
    }
    
    public func swapped() -> SwappedType {
        return CFConvertFloat32SwappedToHost(self)
    }
}

extension CFSwappedFloat64 : PrimitiveMarshallable {
    public typealias SwappedType = Double
    
    public init(swapped: SwappedType) {
        self.init(v: CFConvertFloat64HostToSwapped(swapped).v)
    }
    
    public func swapped() -> SwappedType {
        return CFConvertFloat64SwappedToHost(self)
    }
}

extension String : Marshallable {
    public init?(data: NSData) {
        self.init(data: data, encoding: NSUTF8StringEncoding)
    }
    
    public func marshal() -> NSData {
        return self.dataUsingEncoding(NSUTF8StringEncoding)!
    }
}

extension NSData : Marshallable {
    public func marshal() -> NSData {
        return self
    }
}
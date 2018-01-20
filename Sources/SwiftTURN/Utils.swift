//
//  Utils.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

extension Data {
	
	func hexStr() -> String {
		return [UInt8](self).flatMap { String(format:"0x%02x", $0) }.joined(separator: " ")
	}
	
	func nativeOrderedUInt16(at index: Data.Index) -> UInt16 {
		let value: UInt16 = self.subdata(in: index..<index + MemoryLayout<UInt16>.size).withUnsafeBytes({ $0.pointee })
		return value
	}
	
	func nativeOrderedUInt32(at index: Data.Index) -> UInt32 {
		let value: UInt32 = self.subdata(in: index..<index + MemoryLayout<UInt32>.size).withUnsafeBytes({ $0.pointee })
		return value
	}
	
	func networkOrderedUInt16(at index: Data.Index) -> UInt16 {
		let value: UInt16 = self.subdata(in: index..<index + MemoryLayout<UInt16>.size).withUnsafeBytes({ $0.pointee })
		return value.bigEndian
	}
	
	func networkOrderedUInt32(at index: Data.Index) -> UInt32 {
		let value: UInt32 = self.subdata(in: index..<index + MemoryLayout<UInt32>.size).withUnsafeBytes({ $0.pointee })
		return value.bigEndian
	}
	
	
	mutating func nativeAppendUInt8(_ value: UInt8) {
		var val = value
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
	
	mutating func networkAppendUInt8(_ value: UInt8) {
		var val = value
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
	
	mutating func nativeAppendUInt16(_ value: UInt16) {
		var val = value
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
	
	mutating func networkAppendUInt16(_ value: UInt16) {
		var val = value.bigEndian
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
	
	mutating func nativeAppendUInt32(_ value: UInt32) {
		var val = value
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
	
	mutating func networkAppendUInt32(_ value: UInt32) {
		var val = value.bigEndian
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
}


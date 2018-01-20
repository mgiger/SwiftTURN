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
	
	func nativeOrdered<T: FixedWidthInteger>(at index: Data.Index) -> T {
		let value: T = self.subdata(in: index..<index + MemoryLayout<T>.size).withUnsafeBytes({ $0.pointee })
		return value
	}
	
	func networkOrdered<T: FixedWidthInteger>(at index: Data.Index) -> T {
		let value: T = self.subdata(in: index..<index + MemoryLayout<T>.size).withUnsafeBytes({ $0.pointee })
		return value.bigEndian
	}
	
	mutating func nativeAppend<T: FixedWidthInteger>(_ value: T) {
		var val = value
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
	
	mutating func networkAppend<T: FixedWidthInteger>(_ value: T) {
		var val = value.bigEndian
		self.append(UnsafeBufferPointer(start: &val, count: 1))
	}
}


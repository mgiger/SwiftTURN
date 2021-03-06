//
//  Attributes.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/17/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

let MagicCookie			= UInt32(0x2112A442)
let MagicCookieMSB		= UInt16(MagicCookie >> 16)


enum AttributeType: UInt16 {
	case mappedAddress			= 0x0001
	case username				= 0x0006
	case messageIntegrity		= 0x0008
	case errorCode				= 0x0009
	case unknownAttributes		= 0x000A
	case channelNumber			= 0x000C
	case lifetime				= 0x000D
	case xorPeerAddress			= 0x0012
	case data					= 0x0013
	case realm					= 0x0014
	case nonce					= 0x0015
	case xorRelayedAddress		= 0x0016
	case addressFamily			= 0x0017
	case evenPort				= 0x0018
	case requestedTransport		= 0x0019
	case dontFragment			= 0x001A
	case xorMappedAddress		= 0x0020
	case reservationToken		= 0x0022
	case software				= 0x8022
	case alternateServer		= 0x8023
	case fingerprint			= 0x8028
	case responseOrigin			= 0x802b
	case otherAddress			= 0x802c
	
}


public class Attribute {
	
	var type: AttributeType
	var body = Data()
	
	init(_ attr: AttributeType) {
		type = attr
	}
	
	public var packet: Data {
		var data = Data()
		data.networkAppendUInt16(type.rawValue)
		data.networkAppendUInt16(UInt16(body.count))
		
		// Enforce 32 bit alignment
		if body.count % 4 > 0 {
			body.append(Data(repeating: 0, count: 4 - body.count % 4))
		}
		data.append(body)
		return data
	}
	
	public var description: String {
		return "\(type)"
	}
}

class ErrorCodeAttribute: Attribute {
	let code: UInt16
	let reason: String
	
	init(_ data: Data) {
		code = data.networkOrderedUInt16(at: 2)
//		reason = String(bytes: data[4...], encoding: .utf8) ?? ""
		reason = ""
		
		super.init(.errorCode)
		body = data
		
	}
	init(code errCode: UInt16, reason errReason: String) {
		
		code = errCode
		reason = errReason
		
		super.init(.errorCode)
		body.networkAppendUInt16(code)
		body.append(reason.data(using: .utf8) ?? Data())
	}
	
	override public var description: String {
		return "Error \(code): \(reason)"
	}
}

class MappedAddress: Attribute {
	let address: SocketAddress
	init(_ data: Data) {
		address = SocketAddress(address: data.networkOrderedUInt32(at: 4), port: data.networkOrderedUInt16(at: 2))

		super.init(.mappedAddress)
		body = data
	}
	init(_ addr: SocketAddress) {
		address = addr
		
		super.init(.mappedAddress)
		body.networkAppendUInt8(UInt8(0))
		body.networkAppendUInt8(UInt8(1))
		body.networkAppendUInt16(address.port)
		body.networkAppendUInt32(address.address)
	}
	
	override public var description: String {
		return "MappedAddress: \(address.description)"
	}
}

class XORMappedAddress: Attribute {
	
	let address: SocketAddress	// should always be valid locally
	
	init(attribute: AttributeType, data: Data) {
		
		// xor extracted values
		address = SocketAddress(address: data.networkOrderedUInt32(at: 4) ^ MagicCookie,
								port: data.networkOrderedUInt16(at: 2) ^ MagicCookieMSB)

		super.init(attribute)
		body = data
	}
	init(attribute: AttributeType, addr: SocketAddress) {
		address = addr
		
		super.init(attribute)
		
		// xor it as we package it up
		body.networkAppendUInt8(UInt8(0))
		body.networkAppendUInt8(UInt8(1))
		body.nativeAppendUInt16(address.port ^ MagicCookieMSB.bigEndian)
		body.nativeAppendUInt32(address.address ^ MagicCookie.bigEndian)
//		body.networkAppendUInt16(address.port ^ MagicCookieMSB)
//		body.networkAppendUInt32(address.address ^ MagicCookie)
		
//		((u16bits*)cfield)[1] = (ca->s4.sin_port) ^ nswap16(mc >> 16);
//
//		/* Address */
//		((u32bits*)cfield)[1] = (ca->s4.sin_addr.s_addr) ^ nswap32(mc);
	}
	
	override public var description: String {
		return "XORMappedAddress: \(address.description)"
	}
}

class StringAttribute: Attribute {
	
	let value: String
	
	init(_ type: AttributeType, data: Data) {
		value = String(bytes: data, encoding: .utf8) ?? "??Unknown??"

		super.init(type)
		body = data
	}
	
	init(_ type: AttributeType, value sval: String) {
		value = sval

		super.init(type)
		body.append(value.data(using: .utf8) ?? Data())
	}
	
	override public var description: String {
		return "\(type): \(value)"
	}
}

class DataAttribute: Attribute {
	
	init(data: Data) {
		super.init(.data)
		body = data
	}
	
	override public var description: String {
		let str = String(bytes: body, encoding: .utf8) ?? "??Unknown??"
		return "data: \(str)"
	}
}

class RequestedTransport: Attribute {
	let transport: UInt8 = 17
	init(_ data: Data) {
		super.init(.requestedTransport)
		body = data
	}
	init() {
		super.init(.requestedTransport)
		body.networkAppendUInt8(transport)
		body.networkAppendUInt8(UInt8(0))
		body.networkAppendUInt16(UInt16(0))
	}
	
	override public var description: String {
		return "RequestedTransport: \(transport)"
	}
}

class DontFragment: Attribute {
	init(_ data: Data) {
		super.init(.dontFragment)
	}
	init() {
		super.init(.dontFragment)
	}
	
	override public var description: String {
		return "DontFragment"
	}
}

// can only be IPV4
class AddressFamily: Attribute {
	
	init(_ data: Data) {
		super.init(.addressFamily)
		body = data
	}
	init(name: String) {
		super.init(.addressFamily)
		body.networkAppendUInt32(UInt32(0x01 << 24))
	}
	
	override public var description: String {
		return "AddressFamily"
	}
}

class Lifetime: Attribute {
	
	let lifetime: UInt32
	
	init(seconds: UInt32) {
		lifetime = seconds

		super.init(.lifetime)
		body.networkAppendUInt32(lifetime)
	}
	init(_ data: Data) {
		lifetime = data.networkOrderedUInt32(at: 0)

		super.init(.lifetime)
	}
	
	override public var description: String {
		return "Lifetime: \(lifetime)"
	}
}


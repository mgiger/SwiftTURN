//
//  Attributes.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/17/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

let MagicCookieMSB		= UInt16(0x2112)
let MagicCookie			= UInt32(0x2112A442)


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


class Attribute {
	
	var type: AttributeType
	var body = Data()
	
	init(_ attr: AttributeType) {
		type = attr
	}
	
	public var packet: Data {
		var data = Data()
		data.networkAppend(type.rawValue)
		data.networkAppend(UInt16(body.count))
		
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

class ErrorCode: Attribute {
	let code: UInt16
	let reason: String
	
	init(_ data: Data) {
		code = data.networkOrdered(at: 2)
		reason = String(bytes: data[4...], encoding: .utf8) ?? ""
		
		super.init(.errorCode)
		body = data
		
	}
	init(code errCode: UInt16, reason errReason: String) {
		
		code = errCode
		reason = errReason
		
		super.init(.errorCode)
		body.networkAppend(code)
		body.append(reason.data(using: .utf8) ?? Data())
	}
	
	override public var description: String {
		return "Error \(code): \(reason)"
	}
}

class MappedAddress: Attribute {
	let address: SocketAddress
	init(_ data: Data) {
		address = SocketAddress(address: data.networkOrdered(at: 4), port: data.networkOrdered(at: 2))

		super.init(.mappedAddress)
		body = data
	}
	init(_ addr: SocketAddress) {
		address = addr
		
		super.init(.mappedAddress)
		body.networkAppend(UInt16(0))
		body.networkAppend(address.port)
		body.networkAppend(address.address)
	}
	
	override public var description: String {
		return "MappedAddress: \(address.description)"
	}
}

class XORMappedAddress: Attribute {
	
	let address: SocketAddress	// should always be valid locally
	
	init(attribute: AttributeType, data: Data) {
		
		// xor extracted values
		address = SocketAddress(address: data.networkOrdered(at: 4) ^ MagicCookie,
								port: data.networkOrdered(at: 2) ^ MagicCookieMSB)

		super.init(attribute)
		body = data
	}
	init(attribute: AttributeType, addr: SocketAddress) {
		address = addr
		
		super.init(attribute)
		
		// xor it as we package it up
		body.networkAppend(UInt16(0))
		body.networkAppend(address.port ^ MagicCookieMSB)
		body.networkAppend(address.address ^ MagicCookie)
	}
	
	override public var description: String {
		return "XORMappedAddress: \(address.description)"
	}
}

class StringValue: Attribute {
	
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

class RequestedTransport: Attribute {
	let transport: UInt8 = 17
	init(_ data: Data) {
		super.init(.requestedTransport)
		body = data
	}
	init() {
		super.init(.requestedTransport)
		body.networkAppend(transport)
		body.networkAppend(UInt8(0))
		body.networkAppend(UInt16(0))
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
		body.networkAppend(UInt32(0x01 << 24))
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
		body.networkAppend(lifetime)
	}
	init(_ data: Data) {
		lifetime = data.networkOrdered(at: 0)

		super.init(.lifetime)
	}
	
	override public var description: String {
		return "Lifetime: \(lifetime)"
	}
}


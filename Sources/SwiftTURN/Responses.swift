//
//  Responses.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/17/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

public enum ResponseType: UInt16 {
	case bind					= 0x0101
	case secret					= 0x0102
	case allocate				= 0x0103
	case refresh				= 0x0104
	case activeDestination		= 0x0106
	case connect				= 0x0107
	case permission				= 0x0108
	
	case bindError				= 0x0111
	case secretError			= 0x0112
	case allocateError			= 0x0113
	case refreshError			= 0x0114
	case dataIndication			= 0x0115
	case activeDestinationError	= 0x0116
	case connectError			= 0x0117
	case connectStatus			= 0x0118
}

public enum TURNErrorCode: UInt16 {
	case unknown				= 0
	case tryAlternate			= 300
	case badRequest				= 400
	case unauthorized			= 401
	case forbidden				= 403
	case unknownAttribute		= 420
	case allocationMismatch		= 437
	case staleNonce				= 438
	case wrongCredentials		= 441
	case unsupportedAddress		= 442
	case allocQuotaReached		= 486
	case insufficientCapacity	= 508
}

internal class Response {
	
	public var type: ResponseType
	public var body: Data
	public var attributes = [(AttributeType, Attribute)]()
	
	init(_ respType: ResponseType, body respBody: Data) {
		type = respType
		body = respBody
		
		extractAttributes()
	}
	
	private func extractAttributes() {
		while !body.isEmpty {
			if let (attrType, attr) = nextAttribute() {
				attributes.append((attrType, attr))
			}
		}
	}
	
	public func attribute<T>(type: AttributeType) -> T? {
		for (attrType, attr) in attributes {
			if type == attrType, let typedAttr = attr as? T {
				return typedAttr
			}
		}
		return nil
	}
	
	public func attributes<T>(typed: AttributeType) -> [T] {
		var attrs = [T]()
		for (type, attr) in attributes {
			if type == typed, let typedAttr = attr as? T {
				attrs.append(typedAttr)
			}
		}
		return attrs
	}
	
	func nextAttribute() -> (AttributeType, Attribute)? {
		guard !body.isEmpty else {
			return nil
		}
		
		let attrType = body.networkOrderedUInt16(at: 0)
		let attrLen = body.networkOrderedUInt16(at: 2)
		let length: Int = Int(attrLen) + 4
		let data = Data(body.subdata(in: body.startIndex.advanced(by: 4)..<body.startIndex.advanced(by: length)))
		body = Data(body.subdata(in: body.startIndex.advanced(by: length)..<body.endIndex))
		
		if let type = AttributeType(rawValue: attrType) {
			switch type {
			case .mappedAddress:			return (type, MappedAddress(data))
			case .username:					break
			case .messageIntegrity:			break
			case .errorCode:				return (type, ErrorCodeAttribute(data))
			case .unknownAttributes:		break
			case .channelNumber:			break
			case .lifetime:					return (type, Lifetime(data))
			case .xorPeerAddress:			break
			case .data:						break
			case .realm:					return (type, StringValue(.realm, data: data))
			case .nonce:					break
			case .xorRelayedAddress:		return (type, XORMappedAddress(attribute: .xorRelayedAddress, data: data))
			case .addressFamily:			break
			case .evenPort:					break
			case .requestedTransport:		break
			case .dontFragment:				break
			case .xorMappedAddress:			return (type, XORMappedAddress(attribute: .xorMappedAddress, data: data))
			case .reservationToken:			break
			case .software:					return (type, StringValue(.software, data: data))
			case .alternateServer:			break
			case .fingerprint:				break
			case .responseOrigin:			return (type, MappedAddress(data))
			case .otherAddress:				break
			}
		}
		
		return nil
	}
}


class BindResponse: Response {
	
	init(_ body: Data) {
		super.init(.bind, body: body)
	}
}

class BindErrorResponse: Response {
	
	var code: TURNErrorCode = .unknown
	var reason = "<no error>"
	
	init(_ body: Data) {
		super.init(.bindError, body: body)
		
		if let error: ErrorCodeAttribute = attribute(type: .errorCode) {
			code = TURNErrorCode(rawValue: error.code) ?? .unknown
			reason = error.reason
		}
	}
}

class AllocateResponse: Response {
	
	let address = ChannelAddress()
	var software: String?
	var lifetime: TimeInterval = 0
	
	init(_ body: Data) {
		super.init(.allocate, body: body)
		
		if let addr: XORMappedAddress = attribute(type: .xorRelayedAddress) {
			address.relay = addr.address
		}
		if let addr: XORMappedAddress = attribute(type: .xorMappedAddress) {
			address.reflexive = addr.address
		}
		if let lt: Lifetime = attribute(type: .lifetime) {
			lifetime = TimeInterval(lt.lifetime)
		}
		if let sw: StringValue = attribute(type: .software) {
			software = sw.value
		}
	}
}

class AllocateErrorResponse: Response {
	
	var code: TURNErrorCode = .unknown
	var reason = "<no error>"

	init(_ body: Data) {
		super.init(.allocateError, body: body)
		
		if let error: ErrorCodeAttribute = attribute(type: .errorCode) {
			code = TURNErrorCode(rawValue: error.code) ?? .unknown
			reason = error.reason
		}
	}
}

class RefreshResponse: Response {
	
	var lifetime: TimeInterval = 0
	
	init(_ body: Data) {
		super.init(.allocate, body: body)
		
		if let lt: Lifetime = attribute(type: .lifetime) {
			lifetime = TimeInterval(lt.lifetime)
		}
	}
}

class CreatePermissionRespons: Response {
	
	var addresses = [ChannelAddress]()
	
	init(_ body: Data) {
		super.init(.permission, body: body)
		
		addresses = attributes(typed: .xorPeerAddress)
	}
}

//class ConnectResponse: Response {
//
//	init(_ body: Data) {
//		super.init(.connect, body: body)
//	}
//}
//
//class ConnectErrorResponse: Response {
//
//	init(_ body: Data) {
//		super.init(.connectError, body: body)
//	}
//}
//
//class ConnectStatusResponse: Response {
//
//	init(_ body: Data) {
//		super.init(.connectStatus, body: body)
//	}
//}


//
//  Requests.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/18/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

public enum RequestType: UInt16 {
	case bind					= 0x0001
	case secret					= 0x0002
	case allocate				= 0x0003
	case refresh				= 0x0004
	
	case connect				= 0x0007
	case createPermission		= 0x0008
	case channelBind			= 0x0009
	
	case sendIndication			= 0x0016
	case dataIndication			= 0x0017
}


public class Request: UDPRequest {
	
	public var tranId: Data
	public var attributes: [Attribute]
	public var requestMethod: RequestType
	
	init(_ transactionId: Data, method: RequestType, attrs: [Attribute] = [Attribute]()) {
		requestMethod = method
		tranId = transactionId
		attributes = attrs
	}
	
	public var packet: Data {
		var attrData = Data()
		for attribute in attributes {
			attrData.append(attribute.packet)
		}
		
		let length = UInt16(attrData.count)
		
		// header
		var packet = Data()
		packet.networkAppendUInt16(requestMethod.rawValue)
		packet.networkAppendUInt16(length)
		packet.networkAppendUInt32(MagicCookie)
		packet.append(tranId)
		
		packet.append(attrData)
		return packet
	}
}

class BindRequest : Request {
	
	init(_ transactionId: Data) {
		super.init(transactionId, method: .bind)
	}
}

class AllocateRequest: Request {
	
	init(_ transactionId: Data, lifetime: TimeInterval) {
		super.init(transactionId, method: .allocate)
		
		attributes = [
			RequestedTransport(),
			StringValue(.software, value: "Skeeter 0.1"),
			Lifetime(seconds: UInt32(lifetime))
		]
	}
}

class RefreshRequest: Request {

	init(_ transactionId: Data, lifetime: TimeInterval) {
		super.init(transactionId, method: .refresh)

		attributes = [
			Lifetime(seconds: UInt32(lifetime))
		]
	}
}

class CreatePermission: Request {

	init(_ transactionId: Data, peerAddresses: [ChannelAddress]) {
		super.init(transactionId, method: .createPermission)
		
		// send the relay addresses of the peers we want permissions for
		attributes = peerAddresses.flatMap {
			if let relay = $0.relay {
				return XORMappedAddress(attribute: .xorPeerAddress, addr: relay)
			} else {
				return nil
			}
		}
	}
}


//class DataIndication: Request {
//
//	init(_ transactionId: Data, peerAddress: ChannelAddress) {
//		super.init(transactionId, method: .sendIndication)
//
//		// send the relay addresses of the peers we want permissions for
//		attributes = [
//			XORMappedAddress(attribute: .xorPeerAddress, addr: peerAddress.relay)
//		]
//	}
//}

//class SetActiveDestination: Request {
//	
//	init(_ transactionId: Data, peerAddress: SocketAddress) {
//		super.init(transactionId, method: .setActiveDestination)
//		
//		attributes = [
//			XORMappedAddress(attribute: .xorPeerAddress, addr: peerAddress)
//		]
//	}
//}



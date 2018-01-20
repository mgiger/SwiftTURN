//
//  Peer.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation

public class AddressTuple {
	
	public var local: SocketAddress?
	public var reflexive: SocketAddress?
	public var relay: SocketAddress?
	
	public var description: String {
		return "local: \(local?.description ?? ""), reflexive: \(reflexive?.description ?? ""), relay: \(relay?.description ?? "")"
	}
}
public class Peer {
	
	public var channel: PeerChannel?
	
}

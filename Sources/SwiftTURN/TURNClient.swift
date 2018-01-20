//
//  TURNClient.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

let STUNDesiredLifetime: TimeInterval			= 2 * 60


public protocol TURNClientEventHandlerProtocol {
	
	func registered(address: ChannelAddress)
	func unregistered()
	
	func connect(peer: PeerChannel)
}



public class TURNClient: Peer {
	
	public init(hostname: String) throws {
		
		try super.init(serverHost: hostname)
	}
}

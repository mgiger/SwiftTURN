//
//  TURNClient.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

let STUNDesiredLifetime: TimeInterval			= 1 * 60


public protocol TURNClientEventHandlerProtocol {
	
	func registered(address: AddressTuple)
	func unregistered()
}



public class TURNClient: PeerChannelEventListenerProtocol {
	
	// Generate a unique 96 bit transaction ID
	public var transactionId = Data([UInt8](UUID().uuidString.utf8)[0..<12])
	
	// communications
	private var channel: PeerChannelProtocol
	
	/// For sending refresh packets periodically
	private var refreshTimeout = STUNDesiredLifetime
	
	/// Connection addresses
	private var addresses: AddressTuple?
	private var hasPermission = false
	

	public init(hostname: String) throws {
		
		let address = try SocketAddress(hostname: hostname)
		channel = try PeerChannel(address: address, transactionId: transactionId)
		channel.add(listener: self)
		channel.listenOnSocket()
	}
	
	deinit {
		channel.stopListeningOnSocket()
	}
	
	
	///
	/// Event callbacks
	///
	
	public func bind() {
		
	}
	
	public func bindError() {
		
	}
	
	public func allocate(addresses addr: AddressTuple, lifetime: TimeInterval) {
		addresses = addr
		channel.setRefreshTimeout(timeout: max(lifetime - 60.0, 60.0))
	}
	
	public func allocateError() {
		
	}
	
	public func permission() {
		
	}
	
	public func refresh() {
		
	}
	
	public func connect() {
		
	}
	
	public func connectError() {
		
	}
	
	public func connectStatus() {
		
	}
}


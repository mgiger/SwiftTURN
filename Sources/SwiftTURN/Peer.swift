//
//  Peer.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation

public protocol PeerCommandProtocol {
	
	func openConnection() throws
	func closeConnection()
	
	func request(peers: [ChannelAddress])
}

public protocol PeerEventProtocol {
	
	func allocated()
}

public class Peer: PeerCommandProtocol, PeerChannelEventListenerProtocol {
	
	// Generate a unique 96 bit transaction ID
	public var transactionId = Data([UInt8](UUID().uuidString.utf8)[0..<12])
	
	// communications
	private var channel: PeerChannelCommandProtocol
	
	/// Connection addresses
	public var address: ChannelAddress?
	
	/// Delegate
	private var delegate: PeerEventProtocol
	
	/// Authorized peers
	private var peers = [PeerChannel]()

	
	public var active: Bool {
		return true
	}
	
	
	public init(serverHost: String, delegate owner: PeerEventProtocol) throws {
		
		delegate = owner
		
		let address = ChannelAddress()
		address.relay = try SocketAddress(hostname: serverHost)
		
		channel = PeerChannel(address: address, transactionId: transactionId)
		channel.add(listener: self)
	}
	
	deinit {
		channel.stopListeningOnSocket()
	}
	
	///
	/// Peer commands
	///
	
	public func openConnection() throws {
		try channel.connectSocket()
		channel.listenOnSocket()
	}
	
	public func closeConnection() {
		channel.stopListeningOnSocket()
	}
	
	public func request(peers: [ChannelAddress]) {
		channel.requestPermission(peerAddresses: peers)
	}
	
	
	///
	/// Channel event callbacks
	///
	
	public func bindSuccess() {
		
	}
	
	public func bindError(code: UInt16, message: String) {
		print("bind error (\(code)): \(message)")
		
	}
	
	public func allocateSuccess(address: ChannelAddress, lifetime: TimeInterval) {
		self.address = address
		channel.setRefreshTimeout(timeout: lifetime)
		
		delegate.allocated()
	}
	
	public func allocateError(code: UInt16, message: String) {
		
		print("allocation error (\(code)): \(message)")
	}
	
	public func permissionReceived(addresses: [ChannelAddress]) {
		for address in addresses {
			// new transaction ID here?
			let channel = PeerChannel(address: address, transactionId: transactionId)
			peers.append(channel)
		}
	}
	
	public func refresh(lifetime: TimeInterval) {
		channel.setRefreshTimeout(timeout: lifetime)
	}
	
	public func connect() {
		
	}
	
	public func connectError() {
		
	}
	
	public func connectStatus() {
		
	}
}

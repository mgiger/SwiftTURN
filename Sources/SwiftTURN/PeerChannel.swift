//
//  PeerChannel.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/20/18.
//

import Foundation
import Dispatch

public protocol PeerChannelProtocol {
	
	/// Channel control
	func listenOnSocket()
	func stopListeningOnSocket()
	func setRefreshTimeout(timeout: TimeInterval)
	
	/// Channel commands
	func allocate(lifetime: TimeInterval)
	func permission(peerAddress: SocketAddress)

	/// Listener management
	func add(listener: PeerChannelEventListenerProtocol)
	func remove(listener: PeerChannelEventListenerProtocol)
}

public protocol PeerChannelEventListenerProtocol: class {
	
	// Simple STUN bind interface
	func bind()
	func bindError()
	
	// TURN allocation
	func allocate(addresses: AddressTuple, lifetime: TimeInterval)
	func allocateError()
	
	// TURN permission
	func permission()
	
	func refresh()
	
	func connect()
	func connectError()
	func connectStatus()
}

// make all protocols optional
extension PeerChannelEventListenerProtocol {
	func bind() {}
	func bindError() {}
	func allocate(addresses: AddressTuple, lifetime: TimeInterval) {}
	func allocateError() {}
	func permission() {}
	func refresh() {}
	func connect() {}
	func connectError() {}
	func connectStatus() {}
}



public class PeerChannel: PeerChannelProtocol {
	
	private var socket: UDPSocket
	private var transactionId: Data
	private var listeners = [PeerChannelEventListenerProtocol]()
	private var listening = false
	private var refreshTimeout: TimeInterval = 9 * 60
	private var lastRefresh = Date()
	
	public init(address: SocketAddress, transactionId transId: Data) throws {
		transactionId = transId
		socket = try UDPSocket(address: address, timeout: 1)
	}
	
	
	///
	/// Channel control
	///
	
	public func listenOnSocket() {
		
		guard !listening else {
			assert(!listening, "already listening")
			return
		}
		
		lastRefresh = Date(timeIntervalSinceNow: -refreshTimeout)
		
		listening = true
		DispatchQueue.global().async {
			repeat {
				
				// refresh the channel periodically
				let now = Date()
				if self.lastRefresh.addingTimeInterval(self.refreshTimeout) < now {
					self.refresh()
					self.lastRefresh = now
				}
				
				// wait for messages on the socket
				do {
					if let packet = try self.socket.receive() {
						self.receive(packet: packet)
					}
				} catch SocketError.receiveError {
					
					print("Idle...")
				} catch {

					print("Socket exception: \(error.localizedDescription)")
					self.listening = false
				}
			} while self.listening
		}
	}
	
	public func stopListeningOnSocket() {
		listening = false
	}
	
	public func setRefreshTimeout(timeout: TimeInterval) {
		refreshTimeout = timeout
	}
	
	
	///
	/// channel commands
	///
	
	public func allocate(lifetime: TimeInterval) {
		try? send(request: AllocateRequest(transactionId, lifetime: lifetime))
	}
	
	public func permission(peerAddress: SocketAddress) {
		try? send(request: CreatePermission(transactionId, peerAddress: peerAddress))
	}
	
	public func refresh() {
		
	}
	

	///
	/// Low level send and receive
	///
	
	private func send(request: Request) throws {
		let success = try socket.send(request)
		if !success {
			print("failure to send packet")
		}
	}
	
	private func receive(packet: Data) {
		
		// validate packet
		let transId = packet.subdata(in: packet.startIndex.advanced(by: 8)..<packet.startIndex.advanced(by: 20))
		let cookie = packet.networkOrderedUInt32(at: 4)
		if cookie == MagicCookie, self.transactionId == transId {
			
			// determine packet type
			let messageType = packet.networkOrderedUInt16(at: 0)
			if let responseType = ResponseType(rawValue: messageType) {
				
				// dispatch packet
				let len = Int(packet.networkOrderedUInt16(at: 2))
				let body = Data(packet.subdata(in: packet.startIndex.advanced(by: 20)..<packet.startIndex.advanced(by: 20 + len)))
				
				switch responseType {
				case .bind:
//					let bind = BindResponse(body)
					listeners.forEach { $0.bind() }
					
				case .bindError:
//					let bindError = BindErrorResponse(body)
					listeners.forEach { $0.bindError() }
					
				case .allocate:
					let alloc = AllocateResponse(body)
					listeners.forEach { $0.allocate(addresses: alloc.addressTuple, lifetime: alloc.lifetime) }
					
				case .allocateError:
//					let allocError = AllocateErrorResponse(body)
					listeners.forEach { $0.allocateError() }

				case .permission:
//					let perm = PermissionResponse(body)
					listeners.forEach { $0.permission() }
					
				case .refresh:
//					let refresh = RefreshResponse(body)
					listeners.forEach { $0.refresh() }
					
				case .connect:
//					let connect = ConnectResponse(body)
					listeners.forEach { $0.connect() }
					
				case .connectError:
//					let connectError = ConnectErrorResponse(body)
					listeners.forEach { $0.connectError() }
					
				case .connectStatus:
//					let connectStatus = ConnectStatusResponse(body)
					listeners.forEach { $0.connectStatus() }
					
				default:
					print("Unhandled response type \(responseType)")
				}
			}
		}
	}
	
	
	///
	/// Listener management
	///
	
	public func add(listener: PeerChannelEventListenerProtocol) {
		if listeners.index(where: { $0 === listener }) != nil {
			listeners.append(listener)
		}
	}
	
	public func remove(listener: PeerChannelEventListenerProtocol) {
		if let index = listeners.index(where: { $0 === listener }) {
			listeners.remove(at: index)
		}
	}
}


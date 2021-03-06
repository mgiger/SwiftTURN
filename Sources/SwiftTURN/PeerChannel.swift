//
//  PeerChannel.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/20/18.
//

import Foundation
import Dispatch

let STUNDesiredLifetime: TimeInterval			= 5 * 60


///
/// Channel command dispatch
///
public protocol PeerChannelCommandProtocol {
	
	/// Channel control
	func connectSocket() throws
	func listenOnSocket()
	func stopListeningOnSocket()
	func setRefreshTimeout(timeout: TimeInterval)
	
	/// Request permissions for a set of channel addresses
	///
	/// - Parameter peerAddresses: The set of addresses we would like permissions to read/write from
	func requestPermission(addresses: [ChannelAddress])
	
	/// Send a data packet to a channel address. Try to keep the data small
	///
	/// - Parameters:
	///   - data: Data to send
	///   - to: ChannelAddress of the recipient
	func send(data: Data, to: ChannelAddress)

	
	/// Listener management
	func add(listener: PeerChannelEventListenerProtocol)
	func remove(listener: PeerChannelEventListenerProtocol)
}

///
/// Channel events
///
public protocol PeerChannelEventListenerProtocol: class {
	
	// Simple STUN bind interface
	func bindSuccess()
	func bindError(code: TURNErrorCode, message: String)
	
	// allocation
	func allocate(address: ChannelAddress, lifetime: TimeInterval)
	func allocateError(code: TURNErrorCode, message: String)
	
	// refresh
	func refreshed(lifetime: TimeInterval)
	
	// permission
	func permissionReceived(addresses: [ChannelAddress])
	
	// data
	func received(data: Data, from: ChannelAddress)
	
	func connect()
	func connectError()
	func connectStatus()
}

// make all protocols optional
public extension PeerChannelEventListenerProtocol {
	func bindSuccess() {}
	func bindError(code: TURNErrorCode, message: String) {}
	
//	func allocate(address: ChannelAddress, lifetime: TimeInterval) {}
//	func allocateError(code: TURNErrorCode, message: String) {}
	
	func refreshed(lifetime: TimeInterval) {}
	
	func permission() {}
	
	func dataReceived() {}
	
	func connect() {}
	func connectError() {}
	func connectStatus() {}
}



public class PeerChannel: PeerChannelCommandProtocol {
	
	public var address: ChannelAddress
	
	private var socket: UDPSocket?
	private var transactionId: Data
	private var listeners = [PeerChannelEventListenerProtocol]()
	private var listening = false
	private var allocated = false
	private var refreshTimeout: TimeInterval = STUNDesiredLifetime
	private var lastRefresh = Date()
	
	public init(address addr: ChannelAddress, transactionId transId: Data) {
		transactionId = transId
		address = addr
	}
	
	
	///
	/// Channel control
	///
	public func connectSocket() throws {
		
		guard let relayAddress = address.relay else {
			throw SocketError.badHost
		}
		
		socket = try UDPSocket(address: relayAddress, timeout: 5)
	}
	
	public func listenOnSocket() {
		
		guard !listening else {
			assert(!listening, "already listening")
			return
		}
		
		guard let sock = socket else {
			assert(false, "Socket unavailable")
			return
		}
		
		
		listening = true
		allocated = false
		lastRefresh = Date(timeIntervalSinceNow: -refreshTimeout)
		
		// initiate an allocation on the server
		requestAllocate(lifetime: refreshTimeout)
		
		
		DispatchQueue.global().async {
			
			var idleCount = 0
			repeat {
				
				// refresh the channel periodically
				let now = Date()
				if self.allocated, self.lastRefresh.addingTimeInterval(self.refreshTimeout - 60) < now {
					self.requestRefresh(lifetime: self.refreshTimeout)
					self.lastRefresh = now
				}
				
				// wait for messages on the socket
				do {
					if let packet = try sock.receive() {
						self.receive(packet: packet)
					}
				} catch SocketError.receiveError {
					
					print("Idle \(idleCount)...")
					idleCount = idleCount + 1
					
				} catch {

					print("Socket exception: \(error.localizedDescription)")
					self.stopListeningOnSocket()
					
				}
			} while self.listening
		}
	}
	
	public func stopListeningOnSocket() {
		listening = false
		lastRefresh = Date(timeIntervalSince1970: 0)
		
		// Send a 0 lifetime refresh to the server informing them we're shutting down
		requestRefresh(lifetime: 0)
	}
	
	public func setRefreshTimeout(timeout: TimeInterval) {
		refreshTimeout = timeout
	}
	
	///
	/// channel commands
	///
	
	public func requestPermission(addresses: [ChannelAddress]) {
		try? send(request: CreatePermissionRequest(transactionId, addresses: addresses))
	}
	
	public func send(data: Data, to: ChannelAddress) {
		try? send(request: DataIndicationRequest(transactionId, data: data, to: to))
	}
	

	///
	/// Low level send and receive
	///
	
	private func send(request: Request) throws {
		guard let sock = socket else {
			throw SocketError.allocateError
		}
		
		let success = try sock.send(request)
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
			print("packet 0x\(String(format:"%04x", messageType))")
			if let responseType = ResponseType(rawValue: messageType) {
				
				// dispatch packet
				let len = Int(packet.networkOrderedUInt16(at: 2))
				let body = Data(packet.subdata(in: packet.startIndex.advanced(by: 20)..<packet.startIndex.advanced(by: 20 + len)))
				
				switch responseType {
				case .bind:
					listeners.forEach { $0.bindSuccess() }
					
				case .bindError:
					let bindError = BindErrorResponse(body)
					listeners.forEach { $0.bindError(code: bindError.code, message: bindError.reason) }
					
					
				case .allocate:
					let alloc = AllocateResponse(body)
					allocated = true
					lastRefresh = Date()
					listeners.forEach { $0.allocate(address: alloc.address, lifetime: alloc.lifetime) }
					
				case .allocateError:
					allocated = false
					let allocError = AllocateErrorResponse(body)
					listeners.forEach { $0.allocateError(code: allocError.code, message: allocError.reason) }
					
				case .refresh:
					let refresh = RefreshResponse(body)
					listeners.forEach { $0.refreshed(lifetime: refresh.lifetime) }
					
				case .permission:
					let permissionResponse = CreatePermissionResponse(body)
					listeners.forEach { $0.permissionReceived(addresses: permissionResponse.addresses) }
					
				case .dataIndication:
					print("dataIndication received")
					let dataResponse = DataIndicationResponse(body)
					if let body = dataResponse.data?.body {
						listeners.forEach { $0.received(data: body, from: dataResponse.address) }
					}
					
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
	/// Internal commands
	///
	
	/// Allocate an entry on the server
	///
	/// - Parameter lifetime: Requested lifetime
	private func requestAllocate(lifetime: TimeInterval) {
		try? send(request: AllocateRequest(transactionId, lifetime: lifetime))
	}
	
	/// Send a refresh packet to the server
	///
	/// - Parameter lifetime: Requested lifetime
	private func requestRefresh(lifetime: TimeInterval) {
		try? send(request: RefreshRequest(transactionId, lifetime: lifetime))
	}

	
	///
	/// Listener management
	///
	
	public func add(listener: PeerChannelEventListenerProtocol) {
		if listeners.index(where: { $0 === listener }) == nil {
			listeners.append(listener)
		}
	}
	
	public func remove(listener: PeerChannelEventListenerProtocol) {
		if let index = listeners.index(where: { $0 === listener }) {
			listeners.remove(at: index)
		}
	}
}


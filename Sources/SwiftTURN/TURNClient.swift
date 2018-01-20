//
//  TURNClient.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

let STUNDesiredLifetime: UInt32			= 1 * 60

public class TURNClient {
	
	// Generate a unique 96 bit transaction ID
	public var transactionId = Data([UInt8](UUID().uuidString.utf8)[0..<12])
	
	/// For sending refresh packets periodically
	private var refreshTimeout = STUNDesiredLifetime
	
	/// Connection addresses
	var relayedAddress: SocketAddress?		// TURN server address
	var mappedAddress: SocketAddress?		// Our NAT mapped address
	
	private var internalAddress: SocketAddress?
	private var externalAddress: SocketAddress?

	private var socket: UDPSocket!
	private var socketActive: Bool = true

	public init(hostname: String, port: UInt16) throws {
		
		let address = try SocketAddress(hostname: hostname, port: port)
		socket = try UDPSocket(address)
		
		// Get our internal/external addresses from the STUN bind call
//		try socket.send(BindRequest(transactionId))
	}
	
	public func stop() {
		allocate(lifetime: 0)
		socketActive = false
	}
	
	public func start() {
		
		var refreshTime = Date(timeIntervalSinceNow: -TimeInterval(refreshTimeout))

		DispatchQueue.global().async {
		
			repeat {
				
				// refresh if needed
				if refreshTime <= Date() {
					refreshTime = Date(timeIntervalSinceNow: TimeInterval(self.refreshTimeout))
					self.allocate(lifetime: STUNDesiredLifetime)
				}
				
				do {
					if let packet = try self.socket.receive() {
						
						// validate packet
						let transId = packet[8..<20]
						let cookie: UInt32 = packet.networkOrdered(at: 4)
						if cookie == MagicCookie, self.transactionId == transId {
							
							// determine packet type
							let messageType: UInt16 = packet.networkOrdered(at: 0)
							if let responseType = ResponseType(rawValue: messageType) {
								
								// dispatch packet
								let len: UInt16 = packet.networkOrdered(at: 2)
								self.dispatch(type: responseType, body: Data(packet[20..<20+len]))
							}
							else {
								print("Unknown response: \(String(format:"0x%04x", messageType))")
							}
						}
						else {
							print("Invalid packet")
						}
					}
					
				} catch SocketError.receiveError {
					
					// probably a timeout
					print("Idle...")
					
				} catch {
					
					print("Socket exception: \(error.localizedDescription)")
					self.socketActive = false
				}
				
			} while self.socketActive
		}
	}
	
	private func dispatch(type: ResponseType, body: Data) {
		
		switch type {
			
		case .bind:
			let bind = BindResponse(body)
			print("\(bind)")

		case .bindError:
			let bindError = BindErrorResponse(body)
			print("\(bindError)")

		case .allocate:
			let alloc = AllocateResponse(body)
			refreshTimeout = max(alloc.lifetime - 60, 60)
			relayedAddress = alloc.relayedAddress
			mappedAddress = alloc.mappedAddress
			print("Allocate success from \"\(alloc.software ?? "Unknown")\"")
			
			if let maddr = mappedAddress {
				permission(peerAddress: maddr)
			}
		
		case .permission:
			let perm = PermissionResponse(body)
			print("\(perm)")
			
		case .allocateError:
			let allocError = AllocateErrorResponse(body)
			print("\(allocError)")

		case .refresh:
			let refresh = RefreshResponse(body)
			refreshTimeout = max(refresh.lifetime - 60, 60)
			
		case .connect:
			let connect = ConnectResponse(body)
			print("\(connect)")
			
		case .connectError:
			let connectError = ConnectErrorResponse(body)
			print("\(connectError)")
			
		case .connectStatus:
			let connectStatus = ConnectStatusResponse(body)
			print("\(connectStatus)")

		default:
			print("Unhandled response type \(type)")
		}
	}
	
	
	public func allocate(lifetime: UInt32) {
		print("Issuing allocate request")
		
		_ = try? socket.send(AllocateRequest(transactionId, lifetime: STUNDesiredLifetime))
	}
	
	public func permission(peerAddress: SocketAddress) {
		print("Issuing permission request")
		
		_ = try? socket.send(CreatePermission(transactionId, peerAddress: peerAddress))
	}
}


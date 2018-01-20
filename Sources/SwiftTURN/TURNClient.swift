//
//  TURNClient.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation
import Dispatch

let STUNDesiredLifetime: UInt32			= 1 * 60

public class PeerAddressTuple {
	
	public var local: SocketAddress?
	public var reflexive: SocketAddress?
	public var relay: SocketAddress?
	
}

public class TURNClient {
	
	// Generate a unique 96 bit transaction ID
	public var transactionId = Data([UInt8](UUID().uuidString.utf8)[0..<12])
	
	/// For sending refresh packets periodically
	private var refreshTimeout = STUNDesiredLifetime
	
	/// Connection addresses
	var clientTuple = PeerAddressTuple()

	private var socket: UDPSocket!
	public var socketActive: Bool = true
	
	private var registeredCompletion: ((PeerAddressTuple?) -> Void)?

	public init(hostname: String, port: UInt16) throws {
		
		registeredCompletion = nil
		
		let serverAddress = try SocketAddress(hostname: hostname, port: port)
		socket = try UDPSocket(serverAddress)
	}
	
	public func stop() {
		allocate(lifetime: 0)
		socketActive = false
	}
	
	public func start(registered: @escaping (PeerAddressTuple?) -> Void) {
		
		registeredCompletion = registered
		
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
						let transId = packet.subdata(in: packet.startIndex.advanced(by: 8)..<packet.startIndex.advanced(by: 20))
						let cookie = packet.networkOrderedUInt32(at: 4)
						if cookie == MagicCookie, self.transactionId == transId {
							
							// determine packet type
							let messageType = packet.networkOrderedUInt16(at: 0)
							if let responseType = ResponseType(rawValue: messageType) {
								
								// dispatch packet
								let len = Int(packet.networkOrderedUInt16(at: 2))
								let body = Data(packet.subdata(in: packet.startIndex.advanced(by: 20)..<packet.startIndex.advanced(by: 20 + len)))
								self.dispatch(type: responseType, body: body)
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
			
			clientTuple.local = SocketAddress()
			clientTuple.reflexive = alloc.mappedAddress
			clientTuple.relay = alloc.relayedAddress
			
			print("Allocate success from \"\(alloc.software ?? "Unknown")\"")
			
			if let maddr = alloc.mappedAddress {
				permission(peerAddress: maddr)
			}
		
		case .permission:
			let perm = PermissionResponse(body)
			print("\(perm)")
			
		case .allocateError:
			let allocError = AllocateErrorResponse(body)
			
			registeredCompletion?(nil)
			
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


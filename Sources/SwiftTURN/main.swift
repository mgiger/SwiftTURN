//
//  main.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation
import Dispatch

class HeadlessService: PeerEventProtocol, SignalerEventProtocol {
	
	private var relayClient: Peer?
	private var meetingRoom: Signaler?
	
	
	func connectAsPeer() {
		do {
			relayClient = try Peer(serverHost: "45.32.202.66:3478", delegate: self)
			
			print("connecting...")
			try relayClient?.openConnection()
		} catch {
			print("Exception: \(error.localizedDescription)")
		}
	}
	
	func allocated() {
		guard let address = relayClient?.address else {
			print("Error: failed to allocate client address")
			return
		}
		
		print("allocated peer: \(address)")

		meetingRoom = Signaler(hostServer: "45.32.202.66:8000", delegate: self)
		meetingRoom?.register(identifier: "skeetsy", channel: address)
	}
	
	
	
	public func allocateError(code: TURNErrorCode, message: String) {
		print("allocation error (\(code)): \(message)")
	}
	
	func registered(identifier: String) {
		print("registered \(identifier)")
	}
	
	func registerFailed(identifier: String, message: String) {
		print("register failed \(identifier)")
	}
	func discovered(identifier: String, address: ChannelAddress) {
		
		print("discovered \(identifier) at \(address)")
	}
	
	func discoverFailed(identifier: String, message: String) {
		print("discover failed \(identifier)")
	}
}

let service = HeadlessService()
service.connectAsPeer()

RunLoop.main.run()

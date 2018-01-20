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
	
	
	func allocated() {
		guard let address = relayClient?.address else {
			print("Error: failed to allocate client address")
			return
		}
		
		print("allocated peer: \(address)")
//		
//		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(100), execute: {
//			self.runloop()
//		})
//		
		meetingRoom = Signaler(hostServer: "45.32.202.66:8000", delegate: self)
		meetingRoom?.register(identifier: "skeetsy", channel: address)
		
		runloop()
	}
	
	func registered(identifier: String) {
		print("registered \(identifier)")
	}
	
	func registerFailed(identifier: String) {
		print("register failed \(identifier)")
	}
	func discovered(identifier: String, address: ChannelAddress) {
		
		print("discovered \(identifier) at \(address)")
	}
	
	func discoverFailed(identifier: String) {
		print("discover failed \(identifier)")
	}

	
	func connectAsPeer() {
		do {
			relayClient = try Peer(serverHost: "45.32.202.66:3478", delegate: self)
			try relayClient?.openConnection()
			
		} catch {
			print("Exception: \(error.localizedDescription)")
		}
	}

	public func runloop() {
		
		guard let client = relayClient, client.active else {
			print("Error: no client")
			return
		}
		
		var exiting = false
		DispatchQueue.main.sync {
			
			repeat {
				if !client.active {
					exiting = true
					sleep(1)
				}
			} while !exiting
		}
	}
}

let service = HeadlessService()
service.connectAsPeer()


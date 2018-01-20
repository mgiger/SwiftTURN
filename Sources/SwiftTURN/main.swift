//
//  main.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation
import Dispatch

class HeadlessService: PeerEventProtocol, SignalerEventProtocol {
	
	public var active = false
	
	private var relayClient: Peer?
	private var meetingRoom: Signaler?
	

	func allocated() {
		guard let address = relayClient?.address else {
			return
		}
		
		print("allocated peer: \(address)")
		
		meetingRoom = Signaler(hostServer: "45.32.202.66:8000", delegate: self)
		meetingRoom?.register(identifier: "skeetsy", channel: address)
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

	public init() {
		
		connectAsPeer()
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
		
		guard let client = relayClient else {
			return
		}
		
		var exiting = false
		repeat {
			DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: {
				
				if !client.active {
					exiting = true
				}
			})

		} while !exiting
	}
}

let service = HeadlessService()
service.runloop()


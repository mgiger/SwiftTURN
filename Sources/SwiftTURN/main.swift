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
	
	public init() {
		
		connectAsPeer()
	}
	
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

	
	func connectAsPeer() {
		do {
			relayClient = try Peer(serverHost: "45.32.202.66:3478", delegate: self)
			try relayClient?.openConnection()
			
		} catch {
			print("Exception: \(error.localizedDescription)")
		}
	}

	public func loop() {
		
		guard let client = relayClient, client.active else {
			print("Error: no client")
			return
		}
		
		var exiting = false
		DispatchQueue.main.async {
			repeat {
				if !client.active {
					exiting = true
					sleep(1)
				}
			} while !exiting
		}
	}
	
	public func runloop() {
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(100), execute: {
			self.loop()
		})
	}
}

let service = HeadlessService()
service.runloop()


//
//  Discovery.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/19/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

public protocol SignalerEventProtocol {
	
	func registered(identifier: String)
	func registerFailed(identifier: String)
	
	func discovered(identifier: String, address: ChannelAddress)
	func discoverFailed(identifier: String)
}

public class Signaler {

	private var session: URLSession
	private var host: String
	private var delegate: SignalerEventProtocol

	public init(hostServer addr: String, delegate owner: SignalerEventProtocol) {
		host = addr
		delegate = owner
		session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
	}
	
	public func register(identifier: String, channel: ChannelAddress) {
		let relay = channel.relay?.description ?? ""
		let reflexive = channel.reflexive?.description ?? ""
		let local = channel.local?.description ?? ""
		
		let regUrl = "http://" + host + "/register/" + identifier + "/" + relay + "/" + reflexive + "/" + local + "/"
		print("register \(regUrl)")
		
		if let url = URL(string: regUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
				
				guard error != nil else {
					self?.delegate.registerFailed(identifier: identifier)
					return
				}
				
				self?.delegate.registered(identifier: identifier)
			})
			task.resume()
		}
	}
	
//	public func unregister(identifier: String) {
//		let regUrl = String(format: "http://%@/unregister/%@/", host, identifier)
//		if let url = URL(string: regUrl) {
//
//			let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
//				// whatevs
//			})
//			task.resume()
//		}
//	}
	
	public func discover(identifier: String) {
		
		let discoverUrl = "http://" + host + "/discover/" + identifier + "/"
		print("discover \(discoverUrl)")
		
		if let url = URL(string: discoverUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
				
				guard let data = data, error == nil else {
					self?.delegate.registerFailed(identifier: identifier)
					return
				}
				
				do {
					if let package = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
					
						let peerAddress = ChannelAddress()
						peerAddress.relay = try? SocketAddress(hostname: package["relay"])
						peerAddress.reflexive = try? SocketAddress(hostname: package["reflexive"])
						peerAddress.local = try? SocketAddress(hostname: package["local"])
						
						self?.delegate.discovered(identifier: identifier, address: peerAddress)
					}
				} catch {
					self?.delegate.registerFailed(identifier: identifier)
				}
				
			})
			task.resume()
		}
	}
}

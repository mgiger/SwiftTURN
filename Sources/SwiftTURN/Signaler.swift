//
//  Discovery.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/19/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

public protocol SignalerEventProtocol {
	
	func discovered(identifier: String, address: ChannelAddress)
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
#if os(Linux)
	
		guard let hstr = UnsafePointer<Int8>(host.cString(using: .utf8)) else { return }
		guard let istr = UnsafePointer<Int8>(identifier.cString(using: .utf8)) else { return }
		guard let rlstr = UnsafePointer<Int8>(relay.cString(using: .utf8)) else { return }
		guard let rxstr = UnsafePointer<Int8>(reflexive.cString(using: .utf8)) else { return }
		guard let lstr = UnsafePointer<Int8>(local.cString(using: .utf8)) else { return }
		let regUrl = String(format: "http://%s/register/%s/%s/%s/%s/", hstr, istr, rlstr, rxstr, lstr)
#else
		let regUrl = String(format: "http://%@/register/%@/%@/%@/%@/", host, identifier, relay, reflexive, local)
#endif
		if let url = URL(string: regUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
				// whatevs
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
		
#if os(Linux)
		guard let hstr = UnsafePointer<Int8>(host.cString(using: .utf8)) else { return }
		guard let istr = UnsafePointer<Int8>(identifier.cString(using: .utf8)) else { return }
		let discoverUrl = String(format: "http://%s/discover/%s/", hstr, istr)
#else
		let discoverUrl = String(format: "http://%@/discover/%@/", host, identifier)
#endif
		if let url = URL(string: discoverUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
				if error == nil, let data = data {
					
					do {
						if let package = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
						
							let peerAddress = ChannelAddress()
							peerAddress.relay = try? SocketAddress(hostname: package["relay"])
							peerAddress.reflexive = try? SocketAddress(hostname: package["reflexive"])
							peerAddress.local = try? SocketAddress(hostname: package["local"])
							
							self?.delegate.discovered(identifier: identifier, address: peerAddress)
						}
					} catch {
					}
				}
			})
			task.resume()
		}
	}
}

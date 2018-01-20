//
//  Discovery.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/19/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation


public class Signaler {

	private var session: URLSession
	private var host: String
	
	private var client: ChannelAddress
	

	public init(host hostAddress: String, client clientTuple: ChannelAddress) {
		host = hostAddress
		client = clientTuple
		
		session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
	}
	
	public func register(identifier: String) {
	
		let relay = client.relay?.description ?? ""
		let reflexive = client.reflexive?.description ?? ""
		let local = client.local?.description ?? ""
#if os(Linux)
	
		let hstr = UnsafePointer<Int8>(host.cString(using: .utf8))
		let istr = UnsafePointer<Int8>(identifier.cString(using: .utf8))
		let rlstr = UnsafePointer<Int8>(relay.cString(using: .utf8))
		let rxstr = UnsafePointer<Int8>(reflexive.cString(using: .utf8))
		let lstr = UnsafePointer<Int8>(local.cString(using: .utf8))
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
	
	public func discover(identifier: String, completion: @escaping (ChannelAddress?) -> Void) {
		
#if os(Linux)
		let hstr = UnsafePointer<Int8>(host.cString(using: .utf8))
		let istr = UnsafePointer<Int8>(identifier.cString(using: .utf8))
		let discoverUrl = String(format: "http://%s/discover/%s/", hstr, istr)
#else
		let discoverUrl = String(format: "http://%@/discover/%@/", host, identifier)
#endif
		if let url = URL(string: discoverUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
				if error == nil, let data = data {
					
					do {
						if let package = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
						
							let peerTuple = ChannelAddress()
							peerTuple.relay = try? SocketAddress(hostname: package["relay"])
							peerTuple.reflexive = try? SocketAddress(hostname: package["reflexive"])
							peerTuple.local = try? SocketAddress(hostname: package["local"])
							
							completion(peerTuple)
						}
					} catch {
						completion(nil)
					}
				}
				else {
					completion(nil)
				}
			})
			task.resume()
		}
	}
}

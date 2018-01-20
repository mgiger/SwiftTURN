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
		let regUrl = String(format: "http://%@/register/%@/%@/%@/%@/", host, identifier, relay, reflexive, local)
		if let url = URL(string: regUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
				// whatevs
			})
			task.resume()
		}
	}
	
	public func unregister(identifier: String) {
		let regUrl = String(format: "http://%@/unregister/%@/", host, identifier)
		if let url = URL(string: regUrl) {
			
			let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
				// whatevs
			})
			task.resume()
		}
	}
	
	public func discover(identifier: String, completion: @escaping (ChannelAddress?) -> Void) {
		
		if let url = URL(string: String(format: "http://%@/discover/%@/", host, identifier)) {
			
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

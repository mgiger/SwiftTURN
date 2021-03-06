//
//  SocketAddress.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

#if os(Linux)
	import Glibc
#else
	import Darwin
#endif

public class SocketAddress {
	
	public var address: UInt32 = 0
	public var port: UInt16 = 0
	
	public init(address inAddress: UInt32, port inPort: UInt16) {
		address = inAddress
		port = inPort
	}
	
	public convenience init(hostname: String?) throws {
		
		guard let hostname = hostname else {
			throw SocketError.badHost
		}
		
		let components = hostname.components(separatedBy: ":")
		if components.count < 2 {
			throw SocketError.badHost
		}
		
		try self.init(hostname: components[0], port: UInt16(components[1]) ?? 8000)
	}
	
	public init(hostname: String, port inPort: UInt16) throws {
		
		guard let host = hostname.withCString({ gethostbyname($0) }) else {
			throw SocketError.badHost
		}

		port = inPort
		
		memcpy(&address, host.pointee.h_addr_list[0]!, Int(host.pointee.h_length))
	}
	
	// default to the local address
	public init() {
		var ifaddr : UnsafeMutablePointer<ifaddrs>?
		guard getifaddrs(&ifaddr) == 0 else { return }
		guard let firstAddr = ifaddr else { return }
		
		for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
			let interface = ifptr.pointee
			let addrFamily = interface.ifa_addr.pointee.sa_family
			if addrFamily == sa_family_t(AF_INET) || addrFamily == sa_family_t(AF_INET6) {
				
				let name = String(cString: interface.ifa_name)
				if  name == "en0" {
					let addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1, { (adr) -> sockaddr_in in
						return adr.pointee
					})
					address = UInt32(addr.sin_addr.s_addr).bigEndian
					port = UInt16(addr.sin_port).bigEndian
				}
			}
		}
		freeifaddrs(ifaddr)

	}
	
	public var sockaddr: sockaddr_in {
		var sockaddr = sockaddr_in()
		sockaddr.sin_family = sa_family_t(AF_INET)
		sockaddr.sin_port = in_port_t(port.bigEndian)
		sockaddr.sin_addr = in_addr(s_addr: address)
		return sockaddr
	}
	
	public var sockaddrLen: socklen_t {
		return socklen_t(MemoryLayout<sockaddr_in>.size)
	}
	
	public var description: String {
		return String(format: "%d.%d.%d.%d:%d", (address >> 24) & 0xFF, (address >> 16) & 0xFF, (address >> 8) & 0xFF, address & 0xFF, port)
	}
}


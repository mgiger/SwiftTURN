//
//  UDPSocket.swift
//  SkeeterEater
//
//  Created by Matthew Giger on 1/15/18.
//  Copyright © 2018 Matthew Giger. All rights reserved.
//

import Foundation

#if os(Linux)
	import Glibc
	private let sock_dgram = Int32(SOCK_DGRAM.rawValue)

#else
	import Darwin.C
	private let sock_dgram = SOCK_DGRAM
#endif

enum SocketError: Error {
	case allocateError
	case badHost
	case sendError
	case receiveError
}

public protocol UDPRequest {
	var packet: Data { get }
}


public class UDPSocket {
	
	private var socket_fd: Int32
	private var address: SocketAddress
	
	public init(_ addr: SocketAddress, timeout: Int = 10) throws {
		
		address = addr
		
		socket_fd = socket(AF_INET, sock_dgram, 0)
		if socket_fd < 0 {
			throw SocketError.allocateError
		}
		
		var socktimeout = timeval()
		socktimeout.tv_sec = timeout
		socktimeout.tv_usec = 0
		
		let timesize = socklen_t(MemoryLayout<timeval>.size)
		if setsockopt(socket_fd, SOL_SOCKET, SO_RCVTIMEO, &socktimeout, timesize) < 0 {
			throw SocketError.allocateError
		}
		if setsockopt(socket_fd, SOL_SOCKET, SO_SNDTIMEO, &socktimeout, timesize) < 0 {
			throw SocketError.allocateError
		}
	}
	
	@discardableResult public func send(_ request: UDPRequest) throws -> Bool {
		
		var addr = address.sockaddr
		let addrlen = address.sockaddrLen
		let datalen = request.packet.count
		let bytesSent = request.packet.withUnsafeBytes { (message: UnsafePointer<UInt8>) -> Int in
			return withUnsafePointer(to: &addr, { (pointer) -> Int in
				pointer.withMemoryRebound(to: sockaddr.self, capacity: 1, { (addrptr) -> Int in
					return sendto(socket_fd, message, datalen, 0, addrptr, addrlen)
				})
			})
		}
		
		if bytesSent < 0 {
			throw SocketError.sendError
		}
		
		return bytesSent == datalen
	}
	
	public func receive() throws -> Data? {

		var addr = address.sockaddr
		var addrlen = address.sockaddrLen
		var buffer = [UInt8](repeating: 0, count: 4096)
		let bytesRead = withUnsafeMutablePointer(to: &addr) { (pointer) -> Int in
			pointer.withMemoryRebound(to: sockaddr.self, capacity: 1, { (addrptr) -> Int in
				return recvfrom(socket_fd, UnsafeMutableRawPointer(mutating: buffer), buffer.count, 0, addrptr, &addrlen)
			})
		}
		
		if bytesRead < 0 {
			throw SocketError.receiveError
		}
		
		return Data(buffer: UnsafeBufferPointer(start: &buffer, count: bytesRead))
	}
	
	private func htons(_ value: CUnsignedShort) -> CUnsignedShort {
		return (value << 8) + (value >> 8)
	}
}

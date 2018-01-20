//
//  Channel.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation

public struct CandidatePair {
	public let baseAddress: SocketAddress
	public let peerAddress: SocketAddress
}

public class Channel {
	
	private var pairs: [CandidatePair]
	
	public init(pairs candidatePairs: [CandidatePair]) {
		pairs = candidatePairs
	}
}

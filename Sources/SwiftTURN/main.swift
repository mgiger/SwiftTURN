//
//  main.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation
import Dispatch

do {
	
	let connection = try Peer(serverHost: "45.32.202.66:3478")
	
	var exiting = false
	repeat {
		
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
			if !connection.active {
				exiting = true
			}
		})
		
	} while !exiting

} catch {
	print("Exception: \(error.localizedDescription)")
}


//
//  main.swift
//  SwiftTURN
//
//  Created by Matthew Giger on 1/19/18.
//

import Foundation
import Dispatch

do {
	let turn = try TURNClient(hostname: "45.32.202.66", port: 3478)
	turn.start()
	
	var exiting = false
	repeat {
		
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
			if turn.socketActive {
				exiting = true
			}
		})
		
	} while !exiting

} catch {
	print("Exception: \(error.localizedDescription)")
}


//
//  main.swift
//  
//
//  Created by Dmitriy Borovikov on 20.10.2021.
//

import Foundation
import Puppy
import Logging

setbuf(stdout, nil)

let logLabel = "TestFestoModbus"
let console = ConsoleLogger(logLabel)

let puppy = Puppy.default
puppy.add(console)

LoggingSystem.bootstrap {
    var handler = PuppyLogHandler(label: $0, puppy: puppy)
    // Set the logging level.
    handler.logLevel = .trace
    return handler
}

let log = Logger(label: logLabel)

print("Start")
let festo = TestFestoModbus()
festo.run()

//
//  main.swift
//  
//
//  Created by Dmitriy Borovikov on 20.10.2021.
//

import Foundation
import Puppy
import Logging

let logLabel = "TestFestoModbus"
let console = ConsoleLogger(logLabel)
#if os(macOS)
let syslog = OSLogger(logLabel)
#elseif os(Linux)
let syslog = SystemLogger(logLabel)
#endif

let puppy = Puppy.default
puppy.add(console)
puppy.add(syslog)

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
// RunLoop.main.run()

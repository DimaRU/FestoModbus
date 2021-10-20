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
let console = ConsoleLogger("com.example.yourapp.console")
#if os(macOS)
let syslog = OSLogger("com.example.yourapp.syslog")
#elseif os(Linux)
let syslog = SystemLogger("com.example.yourapp.syslog")
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

let log = Logger(label: "")

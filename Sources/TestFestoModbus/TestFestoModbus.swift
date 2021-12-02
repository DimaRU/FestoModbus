//
//  TestFestoModbus.swift
//  
//
//  Created by Dmitriy Borovikov on 20.10.2021.
//

import Foundation
import FestoModbus

class TestFestoModbus {
    let festo = FestoModbus.init(address: "192.1.1.32", port: 502, maxLevels: 21, levelHeight: 13)

    init() {
        do {
            try festo.connect()
        } catch  {
            print("Connection error \(error)")
            fatalError("Connection error \(error)")
        }
    }

    func run() {
        do {
//            try festo.unlockFestoDrive()
            // try festo.clearError()
            try festo.showState()
        } catch  {
            print("Clear error \(error)")
        }
    }
}

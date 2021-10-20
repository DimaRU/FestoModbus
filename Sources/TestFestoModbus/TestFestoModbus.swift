//
//  TestFestoModbus.swift
//  
//
//  Created by Dmitriy Borovikov on 20.10.2021.
//

import Foundation
import FestoModbus

/*
 "FestoCameraDrive-": {
 "Address": "192.168.75.70",
 "Port": 502,
 "MaxLevels": 21,
 "LevelHeight": 13
 },
 */

class TestFestoModbus {
    let festo = FestoModbus.init(address: "192.168.75.70", port: 502, maxLevels: 21, levelHeight: 13)

    init() {
        do {
            try festo.connect()
        } catch  {
            fatalError("Connection error \(error)")
        }
    }

    func run() {
        do {
            try festo.unlockFestoDrive()
        } catch  {
            fatalError("Run error \(error)")
        }
    }
}

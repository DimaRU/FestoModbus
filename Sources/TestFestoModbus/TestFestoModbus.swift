//
//  TestFestoModbus.swift
//  
//
//  Created by Dmitriy Borovikov on 20.10.2021.
//

import Foundation
import PromiseKit
import FestoModbus

class TestFestoModbus: FestoPromiseProtocol {
    func current(position: Float) {
        print("Pos in motion:", position)
    }

    let festo = FestoPromise(address: "192.1.1.32", port: 502, coefficient: 1000)
    func run() {
        festo.delegate = self
        firstly {
//            festo.driveInit()
//        }.then {
            self.festo.getPosition()
        }.done { pos in
            print("Position:", pos)
        }.then {
            self.festo.travel(to: 30)
        }.then {
            self.festo.getPosition()
        }.done {
            print("Position1:", $0)
        }.catch { error in
            print(error)
        }.finally {
            exit(1)
        }
    }
}

//
//  FestoModbusPromise.swift
//  
//
//  Created by Dmitriy Borovikov on 03.12.2021.
//

import Foundation
import PromiseKit

final public class FestoModbusPromise: FestoModbusProtocol {

    let festoQueue = DispatchQueue.init(label: "FestoModbus", qos: .utility)
    let festoModbus: FestoModbus

    public init(address: String, port: Int32) {
        festoModbus = FestoModbus(address: address, port: port)
        festoModbus.delegate = self
    }

    public func current(position: Float) {
    }

    public func homing() -> Promise<Void> {
        return firstly {
            self.connect()
        }.then(on: festoQueue) {
            self.unlockFestoDriveDirect()
        }.then(on: festoQueue) {
            self.home()
        }.then(on: festoQueue) {
            self.disconnect()
        }
    }


    func clearError() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.clearError()
            seal.fulfill(())
        }
    }

    func connect() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.connect()
            seal.fulfill(())
        }
    }

    func disconnect() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.disconnect()
            seal.fulfill(())
        }
    }

    func forceCancel() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.forceCancel()
            seal.fulfill(())
        }
    }

    func home() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.home()
            seal.fulfill(())
        }
    }

    func isError() -> Promise<Bool> {
        Promise<Bool> { seal in
            let r = try festoModbus.isError()
            seal.fulfill(r)
        }
    }

    func isLocked() -> Promise<Bool> {
        Promise<Bool> { seal in
            let r = try festoModbus.isLocked()
            seal.fulfill(r)
        }
    }

    func lockFestoDrive() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.lockFestoDrive()
            seal.fulfill(())
        }
    }

    func positioning(to pos: Int32, speed: UInt8) -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.positioning(to: pos, speed: speed)
            seal.fulfill(())
        }
    }

    func unlockFestoDriveDirect() -> Promise<Void> {
        Promise<Void> { seal in
            try festoModbus.unlockFestoDriveDirect()
            seal.fulfill(())
        }
    }
}

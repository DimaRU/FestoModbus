//
//  FestoModbusPromise.swift
//  
//
//  Created by Dmitriy Borovikov on 03.12.2021.
//

import Foundation
import PromiseKit

public protocol FestoPromiseProtocol: AnyObject {
    func current(position: Float)
}

final public class FestoPromise: FestoModbusProtocol {
    let festoQueue = DispatchQueue.init(label: "FestoModbus", qos: .utility)
    let festoModbus: FestoModbus
    let coefficient: Float
    public weak var delegate: FestoPromiseProtocol?

    public init(address: String, port: Int32, coefficient: Float) {
        self.coefficient = coefficient
        festoModbus = FestoModbus(address: address, port: port)
        festoModbus.delegate = self
    }

    public func current(position: Int32) {
        let posFloat = Float(position) / coefficient
        delegate?.current(position: posFloat)
    }

    /// Initialize drive for use
    /// - Returns: Promise<Void>
    public func driveInit() -> Promise<Void> {
        Promise { seal in
            festoQueue.async { [self] in
                do {
                    try festoModbus.connect()
                    try festoModbus.unlockFestoDriveDirect()
                    let isReady = try festoModbus.isReady()
                    if !isReady {
                        try festoModbus.home()
                    }
                    festoModbus.disconnect()
                    usleep(100000)
                    seal.fulfill(())
                } catch {
                    seal.reject(error)
                }
            }
        }
    }

    /// Travel to position
    /// - Parameters:
    ///   - pos: position in mm. Must be in 0...300
    public func travel(to pos: Float) -> Promise<Void> {
        Promise { seal in
            festoQueue.async { [self] in
                do {
                    try festoModbus.connect()
                    try festoModbus.unlockFestoDriveDirect()
                    try festoModbus.positioning(to: Int32(pos * self.coefficient), speed: 255)
                    festoModbus.disconnect()
                    usleep(100000)
                    seal.fulfill(())
                } catch {
                    seal.reject(error)
                }
            }
        }
    }

    /// Get current drive position
    public func getPosition() -> Promise<Float> {
        Promise { seal in
            festoQueue.async { [self] in
                do {
                    try festoModbus.connect()
                    try festoModbus.unlockFestoDriveDirect()
                    let pos = try festoModbus.readPosition()
                    festoModbus.disconnect()
                    usleep(100000)
                    seal.fulfill(Float(pos) / self.coefficient)
                } catch {
                    seal.reject(error)
                }
            }
        }
    }

    func readPosition() -> Promise<Int32> {
        Promise<Int32> { seal in
            let pos = try festoModbus.readPosition()
            seal.fulfill(pos)
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
            festoModbus.disconnect()
            usleep(100000)
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

    func isReady() -> Promise<Bool> {
        Promise<Bool> { seal in
            let r = try festoModbus.isReady()
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

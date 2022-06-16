////
/// Festo camera actuator driver
//

import Foundation
import SwiftyModbus
import Logging


public protocol FestoModbusProtocol: AnyObject {
    func current(position: Int32)
}

final public class FestoModbus {
    private let sleepTime: useconds_t = 50000
    private var modbus: SwiftyModbus
    private var logger = Logger(label: "FestoModbus")
    private let retryCount = 10

    public enum FestoError: Error {
        case cancelled
        case faultOrWarn
        case longOperation
        case unknownPosition
        case locked
    }

    public var cancel = false
    public weak var delegate: FestoModbusProtocol?

    /// Initialise
    /// - Parameters:
    ///   - address: Festo drive IP
    ///   - port: tcp port
    public init(address: String, port: Int32) {
        modbus = SwiftyModbus(address: address, port: port)
        modbus.responseTimeout = 1
        modbus.byteTimeout = 0.5
        #if FESTO_DEBUG
        logger.logLevel = .trace
        logger.trace("Festo drive init \(address):\(port)")
        #endif
    }

    /// Connect to drive controller
    public func connect() throws {
        try modbus.connect()
    }

    /// Disconnect drive controller
    public func disconnect() {
        modbus.disconnect()
    }

    deinit {
        modbus.disconnect()
    }

    // MARK: Internal funcs

    func makeRecordSelRequest(ccon: CCON, cpos: CPOS, recno: UInt8) -> [UInt16] {
        var request: [UInt16] = .init(repeating: 0, count: 4)
        #if FESTO_DEBUG
        logger.trace("Send\n\(ccon)\n\(cpos)\nrecno=\(recno)\n")
        #endif
        request.withUnsafeMutableBytes { ptr in
            ptr[1] = ccon.rawValue
            ptr[0] = cpos.rawValue
            ptr[2] = recno
        }
        return request
    }

    func makeDirectModeRequest(ccon: CCON, cpos: CPOS, cdir: CDIR, v1: UInt8, v2: Int32) -> [UInt16] {
        var request: [UInt16] = .init(repeating: 0, count: 4)
        #if FESTO_DEBUG
        logger.trace("Send\n\(ccon)\n\(cpos)\n\(cdir)\n v1=\(v1) v2=\(v2)\n")
        #endif
        request.withUnsafeMutableBytes { ptr in
            ptr[1] = ccon.rawValue
            ptr[0] = cpos.rawValue
            ptr[3] = cdir.rawValue
            ptr[2] = v1
            let v2a = v2.bytes
            ptr[4] = v2a[2]
            ptr[5] = v2a[3]
            ptr[6] = v2a[0]
            ptr[7] = v2a[1]
        }
        return request
    }

    func parceRecordSelResponce(_ responce: [UInt16]) -> (scon: SCON, spos: SPOS, rsb: UInt8) {
        assert(responce.count == 4, "Reply size != 4 \(responce.count)")
        return responce.withUnsafeBytes { ptr in
            let scon = SCON(rawValue: ptr[1])
            let spos = SPOS(rawValue: ptr[0])
            let rsb = ptr[2]
            #if FESTO_DEBUG
            logger.trace("Receive\n\(scon)\n\(spos)\nrsb=\(rsb)\n")
            #endif
            return (scon, spos, rsb)
        }
    }

    func parceDirectModeResponce(_ responce: [UInt16]) -> (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: Int32) {
        assert(responce.count == 4, "Reply size != 4 \(responce.count)")
        return responce.withUnsafeBytes { ptr in
            let scon = SCON(rawValue: ptr[1])
            let spos = SPOS(rawValue: ptr[0])
            let sdir = SDIR(rawValue: ptr[3])
            let v1 = ptr[2]
            let v2: Int32 = (Int32(responce[2]) << 16) | Int32(responce[3])
            #if FESTO_DEBUG
            logger.trace("Receive\n\(scon)\n\(spos)\n\(sdir)\n v1=\(v1) v2=\(v2)\n")
            #endif
            return (scon, spos, sdir, v1, v2)
        }
    }

    func readWriteRecSel(ccon: CCON, cpos: CPOS, recno: UInt8 = 0) throws -> (scon: SCON, spos: SPOS, rsb: UInt8)
    {
        let request = makeRecordSelRequest(ccon: ccon, cpos: cpos, recno: recno)
        let responce = try modbus.writeAndReadRegisters(writeAddr: 0, data: request, readAddr: 0, readCount: 4)
        return parceRecordSelResponce(responce)
    }

    func readWriteDirect(ccon: CCON, cpos: CPOS, cdir: CDIR = [], v1: UInt8 = 0, v2: Int32 = 0) throws ->
                                            (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: Int32)
    {
        let request = makeDirectModeRequest(ccon: ccon, cpos: cpos, cdir: cdir, v1: v1, v2: v2)
        let responce = try modbus.writeAndReadRegisters(writeAddr: 0, data: request, readAddr: 0, readCount: 4)
        return parceDirectModeResponce(responce)
    }

    func readRecSel() throws -> (scon: SCON, spos: SPOS, rsb: UInt8)
    {
        let responce = try modbus.readRegisters(addr: 0, count: 4)
        return parceRecordSelResponce(responce)
    }

    func readDirect() throws -> (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: Int32)
    {
        let responce = try modbus.readRegisters(addr: 0, count: 4)
        return parceDirectModeResponce(responce)
    }

    func writeDirect(ccon: CCON, cpos: CPOS, cdir: CDIR = [], v1: UInt8 = 0, v2: Int32 = 0) throws
    {
        let request = makeDirectModeRequest(ccon: ccon, cpos: cpos, cdir: cdir, v1: v1, v2: v2)
        try modbus.writeRegisters(addr: 0, data: request)
    }

    func writeRecSel(ccon: CCON, cpos: CPOS, recno: UInt8 = 0) throws
    {
        let request = makeRecordSelRequest(ccon: ccon, cpos: cpos, recno: recno)
        try modbus.writeRegisters(addr: 0, data: request)
    }

    // MARK: Public interface


    /// Read current direct position
    /// - Returns: position (Int32), may be signed
    public func readPosition() throws -> Int32 {
        logger.trace(#function)
        let (scon, spos, _, _, v2) = try readDirect()
        guard scon.isDisjoint(with: [.fault, .warn]) else {
            throw FestoError.faultOrWarn
        }
        guard spos.contains(.ref) else {
            throw FestoError.unknownPosition
        }
        return v2
    }

    /// Lock drive
    public func lockFestoDrive() throws {
        logger.trace(#function)
        var scon: SCON
        (scon, _, _) = try readWriteRecSel(ccon: [], cpos: [])

        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            if !scon.contains([.drvEn]) {
                return
            }
            usleep(sleepTime)
            (scon, _, _) = try readRecSel()
        }
        throw FestoError.longOperation
    }

    /// Unlock drive, set record selection state
    public func unlockFestoDriveRecSel() throws {
        logger.trace(#function)
        var scon: SCON
        _ = try readWriteRecSel(ccon: [], cpos: [])
        usleep(sleepTime)
        (scon, _, _) = try readWriteRecSel(ccon: [.drvEn, .opsEn], cpos: [])

        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            guard !scon.contains(.lock) else {
                throw FestoError.locked
            }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            if scon.contains([.drvEn, .opsEn]) {
                return
            }
            usleep(sleepTime)
            (scon, _, _) = try readRecSel()
        }
        throw FestoError.longOperation
    }

    /// Unlock drive and set direct positioning profile
    public func unlockFestoDriveDirect() throws {
        logger.trace(#function)
        var scon: SCON
        var spos: SPOS

        (scon, spos, _, _, _) = try readDirect()
        guard !scon.contains(.lock) else {
            throw FestoError.locked
        }
        if !scon.isDisjoint(with: [.fault, .warn]) {
            try clearError()
            usleep(sleepTime)
            (scon, spos, _, _, _) = try readDirect()
        }
        if scon.contains([.drvEn, .opsEn, .directMode]), spos.contains(.halt) {
            return
        }
        usleep(sleepTime)

        // enable drive
        let _ = try readWriteDirect(ccon: [], cpos: [])
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .direct], cpos: .halt)
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            if scon.contains([.drvEn, .directMode]), spos.contains(.halt) {
                break
            }
            usleep(sleepTime)
            (scon, spos, _, _, _) = try readDirect()
        }
        guard scon.contains([.drvEn, .directMode]), spos.contains(.halt) else {
            throw FestoError.longOperation
        }

        logger.trace("enable operations")
        usleep(sleepTime)
        // enable operations
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: .halt)
        for _ in 1...retryCount * 2 {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            if scon.contains([.drvEn, .opsEn, .directMode]), spos.contains(.halt) {
                return
            }
            usleep(sleepTime)
            (scon, spos, _, _, _) = try readDirect()
        }
        throw FestoError.longOperation
    }

    /// Clear fault or warning state
    public func clearErrorPos() throws {
        logger.trace(#function)
        var scon: SCON
        var spos: SPOS
        (scon, spos, _) = try readWriteRecSel(ccon: [.drvEn, .opsEn, .reset], cpos: [])
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            if scon.isDisjoint(with: [.fault, .warn]) && !spos.contains(.ask) {
                return
            }
            usleep(sleepTime)
            (scon, spos, _) = try readRecSel()
        }
        throw FestoError.longOperation
    }

    /// Clear fault or warning state
    public func clearError() throws {
        logger.trace(#function)
        var scon: SCON
        var spos: SPOS
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .reset, .direct], cpos: [])
        usleep(sleepTime)
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: [])
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            if scon.isDisjoint(with: [.fault, .warn]) && !spos.contains(.ask) {
                logger.trace("error cleared")
                return
            }
            usleep(sleepTime)
            (scon, spos, _, _, _) = try readDirect()
        }
        throw FestoError.longOperation
    }

    /// Check drive locked state
    /// - Returns: true if locked
    public func isLocked() throws -> Bool {
        let (scon, _, _, _, _) = try readDirect()
        return !scon.contains([.drvEn, .opsEn, .directMode])
    }

    /// Check fault / warning state
    /// - Returns: true if fault or warning
    public func isError() throws -> Bool {
        let (scon, _, _, _, _) = try readDirect()
        return !scon.isDisjoint(with: [.fault, .warn])
    }

    /// Check drive ready
    /// - Returns: true if ready
    public func isReady() throws -> Bool {
        let (scon, spos, _, _, _) = try readDirect()
        return scon.contains([.drvEn, .opsEn, .directMode]) && spos.contains([.ref, .mc])
    }

    /// Search home position
    public func home() throws {
        logger.trace(#function)
        var scon: SCON
        var spos: SPOS

        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: [.halt])
        usleep(sleepTime)
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: [.hom, .halt])

        logger.trace("\(#function) wait ask")
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            if spos.contains(.ask), !spos.contains(.mc) {
                break
            }
            if spos.contains([.ref, .mc]) {
                return
            }
            usleep(sleepTime)
            (scon, spos, _, _, _) = try readDirect()
        }
        guard spos.contains(.ask), !spos.contains(.mc) else {
            throw FestoError.longOperation
        }

        usleep(sleepTime * 5)
        logger.trace("\(#function) wait mc")

        for _ in 1...1000 {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            (scon, spos, _, _, _) = try readDirect()
            if spos.contains([.ref, .mc]) {
                return
            }
            usleep(sleepTime * 5)
        }
        throw FestoError.longOperation
    }

    /// Travel to position
    /// - Parameters:
    ///   - pos: Position (signed), depends of drive settings
    ///   - speed: Motion speed 0 - 255, 255 = 100%
    public func positioning(to pos: Int32, speed: UInt8) throws {
        logger.trace(#function)
        var scon: SCON
        var spos: SPOS
        var v2: Int32

        let _ = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct],
                                    cpos: [.halt])
        usleep(sleepTime)
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct],
                                                    cpos: [.start, .halt],
                                                    cdir: [],
                                                    v1: speed, v2: pos)

        // wait ask
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            if spos.contains(.ask), !spos.contains(.mc) {
                break
            }
            usleep(sleepTime)
            (scon, spos, _, _, _) = try readDirect()
        }
        guard spos.contains(.ask) else {
            throw FestoError.longOperation
        }

        usleep(sleepTime * 2)
        // wait mc
        for _ in 1...1000 {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            (scon, spos, _, _, v2) = try readDirect()
            delegate?.current(position: v2)
            if spos.contains([.mc]) {
                return
            }
            usleep(sleepTime * 2)
        }
        throw FestoError.longOperation
    }

    /// Cancel operation and any motion
    public func forceCancel() throws {
        logger.trace(#function)
        cancel = true

        _ = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: [])
        usleep(sleepTime * 10)
        _ = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: [.clear])
    }
}

extension FixedWidthInteger {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}

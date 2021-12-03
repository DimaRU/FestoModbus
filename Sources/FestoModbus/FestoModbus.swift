////
/// Festo camera actuator driver
//

import Foundation
import SwiftyModbus
import Logging


public protocol FestoModbusProtocol: AnyObject {
    func current(position: Float)
}

public class FestoModbus {
    private let sleepTime: useconds_t = 50000
    public enum FestoError: Error {
        case cancelled
        case faultOrWarn
        case longOperation
    }

    private var modbus: SwiftyModbus
    private let logger = Logger(label: "FestoModbus")
    private let retryCount = 10
    public var cancel = false
    public weak var delegate: FestoModbusProtocol?

    public init(address: String, port: Int32) {
        modbus = SwiftyModbus(address: address, port: port)
        modbus.responseTimeout = 1
        modbus.byteTimeout = 0.5
    }

    public func connect() throws {
        try modbus.connect()
    }

    deinit {
        modbus.disconnect()
    }

    func makeRecordSelRequest(ccon: CCON, cpos: CPOS, recno: UInt8) -> [UInt16] {
        var request: [UInt16] = .init(repeating: 0, count: 4)
        logger.trace("Send\n\(ccon)\n\(cpos)\nrecno=\(recno)\n")
        request.withUnsafeMutableBytes { ptr in
            ptr[1] = ccon.rawValue
            ptr[0] = cpos.rawValue
            ptr[2] = recno
        }
        return request
    }

    func makeDirectModeRequest(ccon: CCON, cpos: CPOS, cdir: CDIR, v1: UInt8, v2: Int32) -> [UInt16] {
        var request: [UInt16] = .init(repeating: 0, count: 4)
        logger.trace("Send\n\(ccon)\n\(cpos)\n\(cdir)\n v1=\(v1) v2=\(v2)\n")
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
            logger.trace("Receive\n\(scon)\n\(spos)\nrsb=\(rsb)\n")
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
            logger.trace("Receive\n\(scon)\n\(spos)\n\(sdir)\n v1=\(v1) v2=\(v2)\n")
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

    public func showState() throws {
        let _ = try readDirect()
    }

    public func lockFestoDrive() throws {
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
        var scon: SCON
        _ = try readWriteRecSel(ccon: [], cpos: [])
        usleep(sleepTime)
        (scon, _, _) = try readWriteRecSel(ccon: [.drvEn, .opsEn], cpos: [])

        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
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

    /// Unlock drive and set direct profile (FHPP profile)
    public func unlockFestoDriveDirect() throws {
        var scon: SCON
        var spos: SPOS

        (scon, spos, _, _, _) = try readDirect()
        if !scon.isDisjoint(with: [.fault, .warn]) {
            try clearError()
        }
        if scon.contains([.drvEn, .opsEn, .directMode]), spos.contains(.halt) {
            return
        }

        let _ = try readWriteDirect(ccon: [], cpos: [])
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: .halt)
        for _ in 1...retryCount {
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
    public func clearError() throws {
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

    /// Search home position
    public func home() throws {
        var scon: SCON
        var spos: SPOS
        (scon, spos, _, _, _) = try readWriteDirect(ccon: [.drvEn, .opsEn, .direct], cpos: [.hom, .halt])
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

        sleep(1)

        for _ in 1...100 {
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            (scon, spos, _, _, _) = try readDirect()
            if spos.contains([.ref, .mc]) {
                return
            }
            sleep(1)
        }
        throw FestoError.longOperation
    }

    /// Travel to position
    /// - Parameters:
    ///   - pos: position in mm. Must be in 0...300
    ///   - speed: Motion speed 0 - 255, 255 = 100%
    public func positioning(to pos: Float, speed: UInt8) throws {
        let posInt = Int32(pos * 100)
        try positioningI(to: posInt, speed: speed)
    }

    public func positioningI(to pos: Int32, speed: UInt8) throws {
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

        usleep(sleepTime * 10)
        // wait mc
        for i in 1...200 {
            print(i)
            guard !cancel else { throw FestoError.cancelled }
            guard scon.isDisjoint(with: [.fault, .warn]) else {
                throw FestoError.faultOrWarn
            }
            (scon, spos, _, _, v2) = try readDirect()
            let curPos = Float(v2) / 100
            delegate?.current(position: curPos)
            if spos.contains([.mc]) {
                return
            }
            usleep(sleepTime * 10)
        }
        throw FestoError.longOperation
    }

    /// Cancel operation and any motion
    public func forceCancel() throws {
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

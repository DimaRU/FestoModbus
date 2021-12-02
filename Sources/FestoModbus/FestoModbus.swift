////
/// Festo camera actuator driver
//

import Foundation
import SwiftyModbus
import Logging

extension FixedWidthInteger {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}

public class FestoModbus {
    enum FestoError: Error {
        case cancelled
        case faultOrWarn
        case unlock
    }

    private var modbusQueue = DispatchQueue(label: "TraceWay.festoQueue")
    private var modbus: SwiftyModbus
    private let logger = Logger(label: "FestoModbus")
    private let maxLevels: Int
    private let levelHeight: Int
    private let retryCount = 10
    private var cancel = false

    public init(address: String, port: Int32, maxLevels: Int, levelHeight: Int) {
        self.maxLevels = maxLevels
        self.levelHeight = levelHeight
        modbus = SwiftyModbus(address: address, port: port)
    }

    public func connect() throws {
        try modbus.connect()
    }

    deinit {
        modbus.disconnect()
    }

    public func forceCancel() {
        cancel = true
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

    func makeDirectModeRequest(ccon: CCON, cpos: CPOS, cdir: CDIR, v1: UInt8, v2: UInt32) -> [UInt16] {
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

    func parceDirectModeResponce(_ responce: [UInt16]) -> (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: UInt32) {
        assert(responce.count == 4, "Reply size != 4 \(responce.count)")
        return responce.withUnsafeBytes { ptr in
            let scon = SCON(rawValue: ptr[1])
            let spos = SPOS(rawValue: ptr[0])
            let sdir = SDIR(rawValue: ptr[3])
            let v1 = ptr[2]
            let v2: UInt32 = UInt32(responce[2]) << 16 + UInt32(responce[3])
            logger.trace("Receive\n\(scon)\n\(spos)\n\(sdir)\n v1=\(v1) v2=\(v2)\n")
            return (scon, spos, sdir, v1, v2)
        }
    }

    func readWriteRecSel(ccon: CCON, cpos: CPOS, recno: UInt8 = 0) throws -> (scon: SCON, spos: SPOS, rsb: UInt8)
    {
        let request = makeRecordSelRequest(ccon: ccon, cpos: cpos, recno: recno)
        let responce = try modbus.writeAndReadRegisters(writeAddr: 0, data: request, readAddr: 0, readCount: 4)
        let (scon, spos, rsb) = parceRecordSelResponce(responce)
        guard !scon.contains([.fault, .warn]) else {
            throw FestoError.faultOrWarn
        }
        return (scon, spos, rsb)
    }

    func readWriteDirect(ccon: CCON, cpos: CPOS, cdir: CDIR = [], v1: UInt8 = 0, v2: UInt32 = 0) throws ->
                                            (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: UInt32)
    {
        let request = makeDirectModeRequest(ccon: ccon, cpos: cpos, cdir: cdir, v1: v1, v2: v2)
        let responce = try modbus.writeAndReadRegisters(writeAddr: 0, data: request, readAddr: 0, readCount: 4)
        let (scon, spos, sdir, v1, v2) = parceDirectModeResponce(responce)
        guard !scon.contains([.fault, .warn]) else {
            throw FestoError.faultOrWarn
        }
        return (scon, spos, sdir, v1, v2)
    }

    func readRecSel() throws -> (scon: SCON, spos: SPOS, rsb: UInt8)
    {
        let responce = try modbus.readRegisters(addr: 0, count: 4)
        return parceRecordSelResponce(responce)
    }

    func readDirect() throws -> (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: UInt32)
    {
        let responce = try modbus.readRegisters(addr: 0, count: 4)
        return parceDirectModeResponce(responce)
    }

    func writeDirect(ccon: CCON, cpos: CPOS, cdir: CDIR = [], v1: UInt8 = 0, v2: UInt32 = 0) throws
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
            if !scon.contains([.drvEn]) {
                return
            }
            guard !cancel else { throw FestoError.cancelled }
            usleep(50000)
            (scon, _, _) = try readRecSel()
        }
        throw FestoError.unlock
    }

    public func unlockFestoDrive() throws {
        var scon: SCON
        (scon, _, _) = try readWriteRecSel(ccon: [.drvEn, .opsEn], cpos: [])

        for _ in 1...retryCount {
            if scon.contains([.drvEn, .opsEn]) {
                return
            }
            guard !cancel else { throw FestoError.cancelled }
            usleep(50000)
            (scon, _, _) = try readRecSel()
        }
        throw FestoError.unlock
    }

    public func clearError() throws {
        var scon: SCON
        var spos: SPOS
        (scon, spos, _) = try readWriteRecSel(ccon: [.drvEn, .opsEn, .reset], cpos: [])
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            if !scon.contains(.fault) && !scon.contains(.warn) && !spos.contains(.ask) {
                return
            }
            (scon, spos, _) = try readRecSel()
        }
        throw FestoError.unlock
    }
}

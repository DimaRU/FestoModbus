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

    init(address: String, port: Int32, maxLevels: Int, levelHeight: Int) {
        self.maxLevels = maxLevels
        self.levelHeight = levelHeight
        modbus = SwiftyModbus(address: address, port: port)
    }

    deinit {
        modbus.disconnect()
    }

    func forceCancel() {
        cancel = true
    }

    func makeRecordSelRequest(ccon: CCON, cpos: CPOS, recno: UInt8) -> [UInt16] {
        var request: [UInt16] = .init(repeating: 0, count: 4)
        request.withUnsafeMutableBytes { ptr in
            ptr[0] = ccon.rawValue
            ptr[1] = cpos.rawValue
            ptr[2] = recno
        }
        return request
    }

    func makeDirectModeRequest(ccon: CCON, cpos: CPOS, cdir: CDIR, v1: UInt8, v2: UInt32) -> [UInt16] {
        var request: [UInt16] = .init(repeating: 0, count: 4)
        request.withUnsafeMutableBytes { ptr in
            ptr[0] = ccon.rawValue
            ptr[1] = cpos.rawValue
            ptr[2] = cdir.rawValue
            ptr[3] = v1
            let v2a = v2.bytes
            ptr[4] = v2a[0]
            ptr[5] = v2a[1]
            ptr[6] = v2a[2]
            ptr[7] = v2a[3]
        }
        return request
    }

    func parceRecordSelResponce(_ reply: [UInt16]) -> (scon: SCON, spos: SPOS, rsb: UInt8) {
        assert(reply.count == 4, "Reply size != 4 \(reply.count)")
        return reply.withUnsafeBytes { ptr in
            let scon = SCON(rawValue: ptr[0])
            let spos = SPOS(rawValue: ptr[1])
            let rsb = ptr[2]
            return (scon, spos, rsb)
        }
    }

    func parceDirectModeResponce(_ reply: [UInt16]) -> (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: UInt32) {
        assert(reply.count == 4, "Reply size != 4 \(reply.count)")
        return reply.withUnsafeBytes { ptr in
            let scon = SCON(rawValue: ptr[0])
            let spos = SPOS(rawValue: ptr[1])
            let sdir = SDIR(rawValue: ptr[2])
            let v1 = ptr[3]
            let v2 = ptr.load(fromByteOffset: 4, as: UInt32.self)
            return (scon, spos, sdir, v1, v2)
        }
    }

    private func sendRecSelCmd(ccon: CCON, cpos: CPOS, recno: UInt8 = 0) throws -> (scon: SCON, spos: SPOS, rsb: UInt8)
    {
        let request = makeRecordSelRequest(ccon: ccon, cpos: cpos, recno: recno)
        let responce = try modbus.writeAndReadRegisters(writeAddr: 0, data: request, readAddr: 0, readCount: 4)
        let (scon, spos, rsb) = parceRecordSelResponce(responce)
        guard !scon.contains([.fault, .warn]) else {
            throw FestoError.faultOrWarn
        }
        return (scon, spos, rsb)
    }

    func unlockFestoDrive() throws {
        // emptry cmd
        let _ = try sendRecSelCmd(ccon: [], cpos: [])
        for _ in 1...retryCount {
            guard !cancel else { throw FestoError.cancelled }
            let (scon, _, _) = try sendRecSelCmd(ccon: [.drvEn, .opsEn], cpos: [])
            if scon.contains(.drvEn) {
                return
            }
        }
        throw FestoError.unlock
    }
}

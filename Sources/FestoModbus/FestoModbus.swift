////
///
//

import Foundation
import SwiftyModbus

extension FixedWidthInteger {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}

public struct FestoModbus {
    public var modbusQueue = DispatchQueue(label: "TraceWay.festoQueue")

    public init() {
    }


    func makeRecordSelRequest(ccon: CCON, cpos: CPOS, recno: UInt8) -> [UInt8] {
        var request: [UInt8] = .init(repeating: 0, count: 8)
        request[0] = ccon.rawValue
        request[1] = cpos.rawValue
        request[2] = recno

        return request
    }

    func makeDirectModeRequest(ccon: CCON, cpos: CPOS, cdir: CDIR, v1: UInt8, v2: UInt32) -> [UInt8] {
        var request: [UInt8] = .init(repeating: 0, count: 8)
        request[0] = ccon.rawValue
        request[1] = cpos.rawValue
        request[2] = cdir.rawValue
        request[3] = v1
        let v2a = v2.bytes
        request[4] = v2a[0]
        request[5] = v2a[1]
        request[6] = v2a[2]
        request[7] = v2a[3]
        return request
    }

    func parceRecordSelReply(_ reply: [UInt8]) -> (scon: SCON, spos: SPOS, rsb: UInt8) {
        guard reply.count == 8 else {
            fatalError("Reply size != 8 \(reply.count)")
        }
        let scon = SCON(rawValue: reply[0])
        let spos = SPOS(rawValue: reply[1])
        let rsb = reply[2]
        return (scon, spos, rsb)
    }

    func parceDirectModeReply(_ reply: [UInt8]) -> (scon: SCON, spos: SPOS, sdir: SDIR, v1: UInt8, v2: UInt32) {
        guard reply.count == 8 else {
            fatalError("Reply size != 8 \(reply.count)")
        }
        let scon = SCON(rawValue: reply[0])
        let spos = SPOS(rawValue: reply[1])
        let sdir = SDIR(rawValue: reply[2])
        let v1 = reply[3]
        let v2: UInt32 = reply.withUnsafeBytes {
            let _ = $0.load(as: UInt32.self)
            return $0.load(as: UInt32.self)
        }
        return (scon, spos, sdir, v1, v2)
    }

}

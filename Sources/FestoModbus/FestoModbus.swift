////
///
//

import Foundation
import PromiseKit
import SwiftyModbus

public struct FestoModbus {

    public init() {
    }


    func makeRequest(ccon: CCON, cpos: CPOS, recno: UInt8) -> [UInt8] {
        var request: [UInt8] = .init(repeating: 0, count: 8)
        request[0] = ccon.rawValue
        request[1] = cpos.rawValue
        request[2] = recno
        return request
    }


}

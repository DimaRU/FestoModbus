import XCTest
@testable import FestoModbus
import PromiseKit
import Logging
import LoggingSyslog


final class FestoModbusTests: XCTestCase {
    var festo: FestoPromise!

    override func setUp() {
        setbuf(stdout, nil)

        LoggingSystem.bootstrap {
            var handler = SyslogLogHandler(label: $0, ident: nil, facility: .local1, option:  [.perror])
            handler.logLevel = .trace
            return handler
        }
        festo = FestoPromise(address: "192.1.1.32", port: 502, coefficient: 1000)
    }

    func testExample() throws {
        let expectation = XCTestExpectation(description: "TestFestoEnd")

        festo.delegate = self
        firstly {
            festo.driveInit()
        }.then {
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
            XCTFail(String(describing: error))
        }.finally {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60 * 3)
    }
}

extension FestoModbusTests: FestoPromiseProtocol {
    func current(position: Float) {
        print("Pos in motion:", position)
    }
}

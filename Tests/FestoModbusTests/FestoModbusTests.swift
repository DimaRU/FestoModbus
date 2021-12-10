import XCTest
@testable import FestoModbus
import PromiseKit
import Puppy
import Logging

let console = ConsoleLogger("TestFestoModbus")

final class FestoModbusTests: XCTestCase {
    let festo = FestoPromise(address: "192.1.1.32", port: 502, coefficient: 1000)

    override class func setUp() {
        let puppy = Puppy.default
        puppy.add(console)

        LoggingSystem.bootstrap {
            var handler = PuppyLogHandler(label: $0, puppy: puppy)
            handler.logLevel = .trace
            return handler
        }
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

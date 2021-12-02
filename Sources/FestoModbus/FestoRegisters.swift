import Foundation

/// Control byte 1 (CCON)
struct CCON: OptionSet {
    let rawValue: UInt8
    // ENABLE = 1: Enable drive (controller) =0: Drive(controller)disabled
    static let drvEn = CCON(rawValue: 0x1)
    // = 1: Operation enabled.  Any error will be deleted.
    // = 0: STOP active (cancel emergency ramp + positioning task). The drive stops with maximum braking ramp, the positioning task is reset.
    static let opsEn = CCON(rawValue: 0x2)
    // = 1: Release brake
    // = 0: Activate brake
    static let brake = CCON(rawValue: 0x4)
    // With a rising edge a fault is acknowledged and the fault value is deleted.
    static let reset = CCON(rawValue: 0x8)
    // = 1: The software can only observe the controller; the software cannot take over device control (HMI control) from the software.
    // = 0: The software may take over the device control (in order to modify parameters or to control inputs).
    static let lock = CCON(rawValue: 0x20)
    // OPM1 Select Operating Mode
    static let direct = CCON(rawValue: 0x40)
    static let opm2 = CCON(rawValue: 0x80)
}
extension CCON: CustomStringConvertible {
    @inline(__always) func m(_ value: CCON) -> String {
        self.contains(value) ? "x" : " "
    }
    var description: String {
        "CCON: " +
        "  OPM2 | direc |  Lock | Reset | Brake | Op En | Enable\n" +
        "      " +
        String(format:
        "   %@   |   %@   |   %@   |   %@   |   %@   |   %@   |   %@   ",
        m(.opm2), m(.direct), m(.lock), m(.reset), m(.brake), m(.opsEn), m(.drvEn))
    }
}

/// Control byte 2 (CPOS)
struct CPOS: OptionSet {
    let rawValue: UInt8

    // = 1: Halt is not active
    // = 0: Halt activated (do not cancel braking ramp + positioning task).
    // The axis stops with a defined braking ramp, the positioning task remains active (with B6 the remaining positioning distance can be deleted).
    static let halt = CPOS(rawValue: 0x1)
    // With a rising edge the current setpoint values will be transferred and positioning started (even if record 0 = homing, for example).
    static let start = CPOS(rawValue: 0x2)
    // With a rising edge homing is started with the set parameters.
    static let hom = CPOS(rawValue: 0x4)
    // The drive moves at the specified velocity or rotational speed in the direction of larger actual values, providing the bit is set.
    // The movement begins with the rising edge and ends with the falling edge.
    static let jogp = CPOS(rawValue: 0x8)
    // The drive moves at the specified velocity or rotational speed in the direction of smaller actual values
    static let jogm = CPOS(rawValue: 0x10)
    // At a falling edge the current actual value is imported into the setpoint register of the currently addressed positioning record;
    static let teach = CPOS(rawValue: 0x20)
    // In the "Halt" status a rising edge causes the positioning task to be deleted and transfer to the status "Ready"
    static let clear = CPOS(rawValue: 0x40)
}
extension CPOS: CustomStringConvertible {
    @inline(__always) func m(_ value: CPOS) -> String {
        self.contains(value) ? "x" : " "
    }
    var description: String {
        "CPOS: " +
        " clear | teach |  JogN |  JogP | StHom | StPos | nHalt\n" +
        "      " +
        String(format:
        "   %@   |   %@   |   %@   |   %@   |   %@   |   %@   |   %@   ",
        m(.clear), m(.teach), m(.jogm), m(.jogp), m(.hom), m(.start), m(.halt))
    }
}

/// Control byte 3 (CDIR) Direct mode
struct CDIR: OptionSet {
    let rawValue: UInt8

    // = 0: Setpoint value is absolute
    // = 1: Setpoint value is relative to last setpoint value
    static let abs = CDIR(rawValue: 0x1)
    // 2 1 bit - Control mode
    // 0 0 Profile Position mode
    // 0 1 Profile Torque mode (torque, current)
    // 1 0 Profile Velocity mode (speed) Reserved
    static let controlMode = CDIR(rawValue: 0x6)
    // Profile Position mode
    static let cmPosition = CDIR([])
    // Profile Torque mode (torque, current)
    static let cmTorque = CDIR(rawValue: 0x2)
    // Profile Velocity mode (speed)
    static let cmVelocity = CDIR(rawValue: 0x4)
    // 1: Stroke monitoring not active
    // 0: Stroke monitoring active
    static let xlim = CDIR(rawValue: 0x20)
}
extension CDIR: CustomStringConvertible {
    @inline(__always) func m(_ value: CDIR) -> String {
        self.contains(value) ? "x" : " "
    }
    var description: String {
        "CDIR: " +
        "  Camm |  Velo |  Torq |  Abs  \n" +
        "      " +
        String(format:
        "   %@   |   %@   |   %@   |   %@   ",
        m(.xlim), m(.cmVelocity), m(.cmTorque), m(.abs))
    }
}

/// Status byte 1 (SCON)
struct SCON: OptionSet {
    let rawValue: UInt8

    // 1: Drive (controller) enabled
    static let drvEn = SCON(rawValue: 0x1)
    // 1: Operation enabled, positioning possible
    static let opsEn = SCON(rawValue: 0x2)
    // 1: Warning registered
    static let warn = SCON(rawValue: 0x4)
    // 1: There is a fault or fault reaction is active.
    // Fault code in the diagnostic memory.
    static let fault = SCON(rawValue: 0x8)
    // 1: Load voltage applied
    static let vl24 = SCON(rawValue: 0x10)
    // 1: Device control by software (FCT or DIN)
    // (PLC control is Locked)
    static let lock = SCON(rawValue: 0x20)
    // Operating Mode
    static let opm = SCON(rawValue: 0x60)
    static let opm1 = SCON(rawValue: 0x40)
    static let opm2 = SCON(rawValue: 0x80)
    static let recordSelection = SCON([])
    static let directMode = SCON(rawValue: 0x40)
}

extension SCON: CustomStringConvertible {
    @inline(__always) func m(_ value: SCON) -> String {
        self.contains(value) ? "x" : " "
    }
    var description: String {
        "SCON: " +
        "  OPM2 |  OPM1 |  FCT  | VLoad | Fault |  Warn | Op En | Enable\n" +
        "      " +
        String(format:
        "   %@   |   %@   |   %@   |   %@   |   %@   |   %@   |   %@   |   %@   ",
        m(.opm2), m(.opm1), m(.lock), m(.vl24), m(.fault), m(.warn), m(.opsEn), m(.drvEn))
    }
}

/// Status byte 2 (SPOS)
struct SPOS: OptionSet {
    let rawValue: UInt8

    // = 0: HALT is active
    // = 1: HALT is not active, axis can be moved
    static let halt = SPOS(rawValue: 0x1)
    // = 0: Ready for start (homing, jog)
    // = 1: Start carried out (homing, jog)
    static let ask = SPOS(rawValue: 0x2)
    // = 0: Positioning task active
    // = 1: Positioning task completed, where applicable with error
    static let mc = SPOS(rawValue: 0x4)
    // = 1: Teaching carried out, actual value has been trans­ferred
    // = 0: Ready for teaching
    static let teach = SPOS(rawValue: 0x8)
    // 1: Speed of the axis >= limit value
    static let moving = SPOS(rawValue: 0x10)
    // 1: Following error active
    static let folErr = SPOS(rawValue: 0x20)
    // 1: Axis has left the tolerance window after MC
    static let still = SPOS(rawValue: 0x40)
    // 1: Reference information present, homing not necessary
    static let ref = SPOS(rawValue: 0x80)
}

extension SPOS: CustomStringConvertible {
    @inline(__always) func m(_ value: SPOS) -> String {
        self.contains(value) ? "x" : " "
    }
    var description: String {
        "SPOS: " +
        "  Ref  | Still | FolEr |  Mov  | Teach |  MC   | AskS  | nHalt \n" +
        "      " +
        String(format:
        "   %@   |   %@   |   %@   |   %@   |   %@   |   %@   |   %@   |   %@   ",
        m(.ref), m(.still), m(.folErr), m(.moving), m(.teach), m(.mc), m(.ask), m(.halt))
    }
}

/// Status byte 3 (SDIR) - Direct mode
struct SDIR: OptionSet {
    let rawValue: UInt8

    // = 0: Setpoint value is absolute
    // = 1: Setpoint value is relative to last setpoint value
    static let abs = SDIR(rawValue: 0x1)
    // 2 1 bit - Control mode
    // 0 0 Profile Position mode
    // 0 1 Profile Torque mode (torque, current)
    // 1 0 Profile Velocity mode (speed) Reserved
    static let controlMode = SDIR(rawValue: 0x6)
    // Profile Position mode
    static let cmPosition = SDIR([])
    // Profile Torque mode (torque, current)
    static let cmTorque = SDIR(rawValue: 0x2)
    // Profile Velocity mode (speed)
    static let cmVelocity = SDIR(rawValue: 0x4)
    // Speed limit reached
    // = 1: Speed limit reached
    // = 0: Speed limit not reached
    static let vlim = SDIR(rawValue: 0x10)
    // Stroke limit reached
    // = 1: Stroke limit reached
    // = 0: Stroke limit not reached
    static let xlim = SDIR(rawValue: 0x20)
}

extension SDIR: CustomStringConvertible {
    @inline(__always) func m(_ value: SDIR) -> String {
        self.contains(value) ? "x" : " "
    }
    var description: String {
        "SDIR: " +
        "  XLim |  VLim |  Velo |  Torq |  Abs  \n" +
        "      " +
        String(format:
        "   %@   |   %@   |   %@   |   %@   |   %@   ",
        m(.xlim), m(.vlim), m(.cmVelocity), m(.cmTorque), m(.abs))
    }
}

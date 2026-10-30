import CoreGraphics
import CoreFoundation
import Foundation

// Diagnostic: log keyDown/keyUp/flagsChanged with keycode and raw flags.
// Usage: swift keytap.swift [seconds]

let duration = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? 300) : 300
let df = DateFormatter(); df.dateFormat = "HH:mm:ss.SSS"

func fmt(_ f: CGEventFlags) -> String {
    var a: [String] = []
    if f.contains(.maskAlphaShift) { a.append("CAPS") }
    if f.contains(.maskShift) { a.append("SHIFT") }
    if f.contains(.maskControl) { a.append("CTRL") }
    if f.contains(.maskAlternate) { a.append("OPT") }
    if f.contains(.maskCommand) { a.append("CMD") }
    if f.contains(.maskSecondaryFn) { a.append("FN") }
    return a.isEmpty ? "-" : a.joined(separator: "+")
}

let mask = (1 << CGEventType.keyDown.rawValue)
         | (1 << CGEventType.keyUp.rawValue)
         | (1 << CGEventType.flagsChanged.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: { _, type, event, _ in
        let kc = event.getIntegerValueField(.keyboardEventKeycode)
        let fl = event.flags
        let auto = event.getIntegerValueField(.keyboardEventAutorepeat)
        let src = event.getIntegerValueField(.eventSourceUnixProcessID)
        let t: String
        switch type {
        case .keyDown: t = "DOWN "
        case .keyUp: t = "UP   "
        case .flagsChanged: t = "FLAGS"
        default: t = "OTHER"
        }
        print("\(df.string(from: Date())) \(t) kc=\(kc) [\(fmt(fl))] raw=\(fl.rawValue) rep=\(auto) pid=\(src)")
        fflush(stdout)
        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
) else {
    print("TAP_CREATE_FAILED (no Accessibility/Input Monitoring permission?)")
    exit(2)
}

let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("TAP_OK")
fflush(stdout)
DispatchQueue.main.asyncAfter(deadline: .now() + duration) { exit(0) }
CFRunLoopRun()

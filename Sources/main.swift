import CoreGraphics
import Foundation

// duration <= 0  => run forever
let duration = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? -1) : -1

let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
    | (1 << CGEventType.keyUp.rawValue)
    | (1 << CGEventType.flagsChanged.rawValue)

// Per-key debounce thresholds (seconds).
// N (kc=45) chatters for ~60-80 ms on a failing butterfly keyboard.
let perKey: [Int64: Double] = [45: 0.090]
let defaultThreshold: Double = 0.015

var lastDown: [Int64: Double] = [:]
var suppressUp: [Int64: Int] = [:]
var downKeys = Set<Int64>()
var genuineCaps = false
var activeTap: CFMachPort?

func uptime() -> Double { ProcessInfo.processInfo.systemUptime }

func logLine(_ s: String) {
    print(s)
    fflush(stdout)
}

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: { _, type, event, _ in
        // The system disables slow/idle taps. Re-enable immediately.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = activeTap {
                CGEvent.tapEnable(tap: t, enable: true)
                logLine("TAP_REENABLED")
            }
            return Unmanaged.passUnretained(event)
        }

        let kc = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            let rep = event.getIntegerValueField(.keyboardEventAutorepeat)
            if rep == 0 {
                // When no key is held, the flag reflects the real Caps Lock state.
                if downKeys.isEmpty {
                    genuineCaps = event.flags.contains(.maskAlphaShift)
                }
                let threshold = perKey[kc] ?? defaultThreshold
                let now = uptime()
                if let last = lastDown[kc], now - last < threshold {
                    // Duplicate key-down: swallow it and its matching key-up.
                    suppressUp[kc, default: 0] += 1
                    return nil
                }
                lastDown[kc] = now
                downKeys.insert(kc)
            }
        } else if type == .keyUp {
            if let pending = suppressUp[kc], pending > 0 {
                suppressUp[kc] = pending - 1
                return nil
            }
            downKeys.remove(kc)
        } else if type == .flagsChanged {
            if downKeys.isEmpty {
                genuineCaps = event.flags.contains(.maskAlphaShift)
            }
        }

        // Force AlphaShift to the genuine state. This drops the rollover glitch
        // without touching the Unicode string (which would break IME composition).
        var flags = event.flags
        if genuineCaps {
            flags.insert(.maskAlphaShift)
        } else {
            flags.remove(.maskAlphaShift)
        }
        if flags != event.flags {
            event.flags = flags
        }

        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
) else {
    logLine("TAP_FAILED (need Accessibility permission)")
    exit(2)
}

activeTap = tap

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
logLine("TAP_OK")

// Watchdog: if the tap gets disabled (sleep/wake, timeout), turn it back on.
let watchdog = DispatchSource.makeTimerSource(queue: .main)
watchdog.schedule(deadline: .now() + 3, repeating: 3)
watchdog.setEventHandler {
    if let t = activeTap, !CGEvent.tapIsEnabled(tap: t) {
        CGEvent.tapEnable(tap: t, enable: true)
        logLine("TAP_REENABLED (watchdog)")
    }
}
watchdog.resume()

if duration > 0 {
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { exit(0) }
}
CFRunLoopRun()

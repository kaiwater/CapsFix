import CoreGraphics
import Foundation

// Diagnostic: poll the combined session modifier state and log changes.
// Usage: swift flagwatch.swift [seconds]

let duration = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? 300) : 300
let start = Date()
var last = CGEventSource.flagsState(.combinedSessionState)
let df = DateFormatter(); df.dateFormat = "HH:mm:ss.SSS"

func desc(_ f: CGEventFlags) -> String {
    var a: [String] = []
    if f.contains(.maskAlphaShift) { a.append("CAPS") }
    if f.contains(.maskShift) { a.append("SHIFT") }
    if f.contains(.maskControl) { a.append("CTRL") }
    if f.contains(.maskAlternate) { a.append("OPT") }
    if f.contains(.maskCommand) { a.append("CMD") }
    if f.contains(.maskSecondaryFn) { a.append("FN") }
    return a.isEmpty ? "-" : a.joined(separator: "+")
}

print("START \(df.string(from: Date())) initial=[\(desc(last))] raw=\(last.rawValue)")
fflush(stdout)
while Date().timeIntervalSince(start) < duration {
    let f = CGEventSource.flagsState(.combinedSessionState)
    if f != last {
        print("\(df.string(from: Date()))  [\(desc(f))]  raw=\(f.rawValue)")
        fflush(stdout)
        last = f
    }
    usleep(1000)
}
print("END \(df.string(from: Date()))")
fflush(stdout)

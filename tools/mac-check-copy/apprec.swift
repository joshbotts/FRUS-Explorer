// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Records a part of the screen to a .mov through ScreenCaptureKit, leaving the Claude app's windows
// out, for recordings of the Mac check copy made while computer use drives it.
//
//     swiftc -O -o "$MAC_CHECK_SCRATCH/apprec" tools/mac-check-copy/apprec.swift
//     "$MAC_CHECK_SCRATCH/apprec" 20 "$MAC_CHECK_SCRATCH/take.mov" 100,80,1440,900
//
// Arguments: the seconds to record, the output file, and the rectangle as x,y,w,h in display points
// from the top left; `--window <CGWindowID>` records that one window instead, and `--no-cursor`
// leaves the pointer out. It writes H.264 at up to 60 frames a second, at the display's pixel scale,
// and needs the Screen Recording permission, as `screencapture` does.
//
// Why it exists (2026-10-21, the build-51 sitting S4, #1763): while computer use drives the copy,
// the Claude app draws its own windows on the screen, and a recording of the screen takes them in:
// a `screencapture -v` test showed the Claude app's panel over the copy. A display capture that
// leaves out the Claude app's windows does not. S4 made recording A and the Mac App Preview's pass B
// with this, at 3420×1924.
//
// Version history:
//   1.0 — #1763: S4's sitting helper

import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 4, let seconds = Double(args[1]) else {
    FileHandle.standardError.write("usage: apprec <seconds> <out.mov> <x,y,w,h> [--window id] [--no-cursor]\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: args[2])
let r = args[3].split(separator: ",").compactMap { Double($0) }
guard r.count == 4 else { exit(2) }
let rect = CGRect(x: r[0], y: r[1], width: r[2], height: r[3])
var windowID: CGWindowID? = nil
var cursor = true
var i = 4
while i < args.count {
    if args[i] == "--window", i + 1 < args.count { windowID = CGWindowID(args[i + 1]); i += 2; continue }
    if args[i] == "--no-cursor" { cursor = false }
    i += 1
}

/// Reports the recording's and the stream's progress and failures on standard output.
final class Delegate: NSObject, SCRecordingOutputDelegate, SCStreamDelegate {
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) { print("recording started") }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { print("recording failed: \(error)") }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { print("recording finished") }
    func stream(_ stream: SCStream, didStopWithError error: Error) { print("stream stopped: \(error)") }
}

let sema = DispatchSemaphore(value: 0)
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else { print("no display"); exit(1) }
        let filter: SCContentFilter
        if let windowID, let w = content.windows.first(where: { $0.windowID == windowID }) {
            filter = SCContentFilter(desktopIndependentWindow: w)
        } else {
            // A display capture that leaves out only the Claude app's windows (its takeover glow and
            // panel). Including the copy's app instead makes macOS badge each captured window's
            // traffic lights with a sharing pill; a display capture does not.
            let excluded = content.applications.filter { $0.bundleIdentifier == "com.anthropic.claudefordesktop" }
            print("excluding \(excluded.map { $0.bundleIdentifier })")
            filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
        }
        let cfg = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        if windowID == nil { cfg.sourceRect = rect }
        cfg.width = Int((windowID == nil ? rect.width : filter.contentRect.width) * scale)
        cfg.height = Int((windowID == nil ? rect.height : filter.contentRect.height) * scale)
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        cfg.showsCursor = cursor
        cfg.queueDepth = 6
        cfg.backgroundColor = .black
        let rcfg = SCRecordingOutputConfiguration()
        rcfg.outputURL = out
        rcfg.outputFileType = .mov
        rcfg.videoCodecType = .h264
        let delegate = Delegate()
        let rec = SCRecordingOutput(configuration: rcfg, delegate: delegate)
        let stream = SCStream(filter: filter, configuration: cfg, delegate: delegate)
        try stream.addRecordingOutput(rec)
        try await stream.startCapture()
        print("capturing \(cfg.width)x\(cfg.height) for \(seconds)s -> \(out.path)")
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        try await stream.stopCapture()
        try? await Task.sleep(nanoseconds: 700_000_000)
        _ = delegate
        sema.signal()
    } catch {
        print("error: \(error)")
        exit(1)
    }
}
sema.wait()

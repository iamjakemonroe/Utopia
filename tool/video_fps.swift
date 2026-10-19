// How smoothly an app drew in a screen recording: the new frames it drew
// each second (a recording repeats the last frame when nothing changes, so
// identical frames are the app not keeping up), and its longest freezes.
// Only the area between [top] and [bottom] (pixels) is compared, to leave
// out a browser's own bars.
//
//   swiftc -O tool/video_fps.swift -o /tmp/video_fps
//   /tmp/video_fps recording.MP4 360 2300
import AVFoundation

let args = CommandLine.arguments
guard args.count >= 2 else {
  print("usage: video_fps <video> [top] [bottom]")
  exit(1)
}
let top = args.count > 2 ? Int(args[2])! : 0
let bottom = args.count > 3 ? Int(args[3])! : Int.max
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let ready = DispatchSemaphore(value: 0)
var track: AVAssetTrack!
Task {
  track = try! await asset.loadTracks(withMediaType: .video).first!
  ready.signal()
}
ready.wait()
let reader = try! AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
])
output.alwaysCopiesSampleData = false
reader.add(output)
reader.startReading()

let changed = 0.05  // mean difference above encoder noise: a real redraw
var previous: [UInt8] = []
var drawn: [Int: Int] = [:]
var freezes: [(Double, Int)] = []
var frozenSince: Double?
var frozenFrames = 0
while let sample = output.copyNextSampleBuffer() {
  guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
  let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  let width = CVPixelBufferGetWidth(buffer)
  let height = CVPixelBufferGetHeight(buffer)
  let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
  let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
  var current: [UInt8] = []
  var y = top
  while y < min(bottom, height) {
    var x = 0
    while x < width {
      let p = base + y * rowBytes + x * 4
      current.append(UInt8((Int(p[0]) + Int(p[1]) * 2 + Int(p[2])) >> 2))
      x += 6
    }
    y += 6
  }
  CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
  if previous.count == current.count {
    var sum = 0
    for i in 0..<current.count { sum += abs(Int(current[i]) - Int(previous[i])) }
    let isNew = Double(sum) / Double(current.count) > changed
    if isNew {
      drawn[Int(t), default: 0] += 1
      if let since = frozenSince, frozenFrames >= 6 { freezes.append((since, frozenFrames)) }
      frozenSince = nil
      frozenFrames = 0
    } else {
      if frozenSince == nil { frozenSince = t }
      frozenFrames += 1
    }
  }
  previous = current
}
let last = drawn.keys.max() ?? 0
print("new frames drawn each second (60 is smooth):")
print((0...last).map { "\($0)s:\(drawn[$0] ?? 0)" }.joined(separator: " "))
print("longest freezes:")
for (at, frames) in freezes.sorted(by: { $0.1 > $1.1 }).prefix(10) {
  print(String(format: "  at %.2fs: %.0f ms", at, Double(frames) * 1000 / 60))
}

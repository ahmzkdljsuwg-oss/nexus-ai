import Foundation
import Vision
import AppKit

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path) else { exit(2) }
var rect = NSRect(origin: .zero, size: image.size)
guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { exit(3) }
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["en-US", "ar-SA"]
let handler = VNImageRequestHandler(cgImage: cg)
try handler.perform([request])
for result in request.results ?? [] {
  if let text = result.topCandidates(1).first?.string { print(text) }
}

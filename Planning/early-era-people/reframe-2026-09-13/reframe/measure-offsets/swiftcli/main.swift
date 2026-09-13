// Scratch CLI (#234 reframe, measure-offsets). Reads "volume<TAB>documentId" lines from argv[1],
// parses each volume with the app's FRUSDocumentParser, converts with ASTToRenderNodeConverter
// (no lookups: persName/gloss/broken-ref lookups add no characters), and writes one JSON line per
// requested document: the highlight flat text (buildFlatText), the block partition size, and the
// footnote flat text. Writes to argv[2].
import Foundation
let args = CommandLine.arguments
let volumesDir = URL(fileURLWithPath: "/Users/jbotts/Development/frus/volumes")
let lines = try String(contentsOfFile: args[1], encoding: .utf8).split(separator: "\n")
var wanted: [String: Set<String>] = [:]
var order: [String] = []
for l in lines {
    let p = l.split(separator: "\t").map(String.init)
    if wanted[p[0]] == nil { order.append(p[0]) }
    wanted[p[0], default: []].insert(p[1])
}
let parser = FRUSDocumentParser()
var out = ""
let t0 = Date()
for vol in order {
    let url = volumesDir.appendingPathComponent(vol + ".xml")
    let asts = try await parser.parse(volumeURL: url)
    for ast in asts where wanted[vol]!.contains(ast.documentId) {
        var conv = ASTToRenderNodeConverter()
        let model = conv.convert(ast)
        let flat = buildFlatText(from: model)
        let blocks = buildFlatTextBlocks(from: model)
        let fn = model.footnotes.map { flatText(of: [$0]) }
        let obj: [String: Any] = ["volume": vol, "d": ast.documentId, "flat": flat, "flat_utf16": flat.utf16.count,
                                  "flat_scalars": flat.unicodeScalars.count, "blocks": blocks.count, "footnotes": fn,
                                  "rendering_version": ASTToRenderNodeConverter.renderingVersion(for: model)]
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        out += String(data: data, encoding: .utf8)! + "\n"
    }
}
try out.write(toFile: args[2], atomically: true, encoding: .utf8)
FileHandle.standardError.write("volumes \(order.count) seconds \(Date().timeIntervalSince(t0))\n".data(using: .utf8)!)

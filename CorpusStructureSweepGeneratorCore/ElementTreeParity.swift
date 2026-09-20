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

import Foundation

/// Cross-checks the byte scan against a real XML parse, on every file, every run.
///
/// **This check is not optional and it has already earned itself.** The first version of the
/// scanner disagreed with an element tree on exactly three files: the `frus1917-72PubDip` volumes
/// embed an XHTML video player whose markup contains `<div>`, in a foreign default namespace, and
/// counting those desynchronises the tree for the remainder of the file — which would silently
/// move every byte offset the report prints after that point.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum ElementTreeParity {

    /// Returns a description of the first disagreement, or `nil` when the two agree.
    public static func check(data: Data, against nodes: [DivNode]) -> String? {
        let parser = XMLParser(data: data)
        let delegate = TreeDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return "the file does not parse as XML" }
        let scanned = nodes.map { Signature(depth: $0.depth, type: $0.type, subtype: $0.subtype,
                                            id: $0.id, n: $0.n) }
        guard scanned.count == delegate.signatures.count else {
            return "byte scan found \(scanned.count) divs, element tree \(delegate.signatures.count)"
        }
        for (index, pair) in zip(scanned, delegate.signatures).enumerated() where pair.0 != pair.1 {
            return "div \(index) differs: scan \(pair.0), tree \(pair.1)"
        }
        return nil
    }

    /// The facts both sides must agree on, in document order.
    struct Signature: Equatable, CustomStringConvertible {
        let depth: Int
        let type: String
        let subtype: String?
        let id: String?
        let n: String?
        var description: String {
            "(\(depth), \(type), \(subtype ?? "-"), \(id ?? "-"), \(n ?? "-"))"
        }
    }

    /// Collects the same signatures from a real parse.
    private final class TreeDelegate: NSObject, XMLParserDelegate {
        var signatures: [Signature] = []
        private var depth = 0

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String]) {
            guard localName(elementName, qName) == "div" else { return }
            // The foreign-namespace player markup, excluded exactly as the scanner excludes it.
            if let declared = attributeDict["xmlns"], declared != "http://www.tei-c.org/ns/1.0" {
                return
            }
            signatures.append(Signature(depth: depth, type: attributeDict["type"] ?? "",
                                        subtype: attributeDict["subtype"],
                                        id: attributeDict["xml:id"], n: attributeDict["n"]))
            depth += 1
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            guard localName(elementName, qName) == "div" else { return }
            depth = max(0, depth - 1)
        }

        private func localName(_ elementName: String, _ qName: String?) -> String {
            let name = qName ?? elementName
            if let colon = name.lastIndex(of: ":") { return String(name[name.index(after: colon)...]) }
            return name
        }
    }
}

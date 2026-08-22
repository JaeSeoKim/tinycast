import Foundation

/// A release body as the update window reads it: the changelog CI generates, split into the handful
/// of block shapes it actually emits.
enum ReleaseNotes {
    /// CI writes the install instructions below this line for the download page — a window that
    /// updates itself has no use for them.
    static let installMarker = "<!-- tinycast:install -->"

    /// The app-facing half of a release body. A body published before the marker existed has no
    /// marker, and comes back whole.
    static func summary(of body: String) -> String {
        let head = body.range(of: installMarker).map { String(body[..<$0.lowerBound]) } ?? body
        return head.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum Block: Hashable, Sendable {
        case heading(level: Int, text: String)
        case bullet(String)
        case paragraph(String)
    }

    /// A line scanner over what GitHub's release-notes API produces, not a general Markdown parser.
    static func blocks(from summary: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []

        func flush() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }

        for raw in summary.replacingOccurrences(of: "\r\n", with: "\n").split(
            separator: "\n", omittingEmptySubsequences: false)
        {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if let heading = heading(in: line) {
                flush()
                blocks.append(heading)
            } else if let bullet = bullet(in: line) {
                flush()
                blocks.append(.bullet(bullet))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    private static func heading(in line: String) -> Block? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count), line.dropFirst(hashes.count).first == " " else { return nil }
        // Markdown lets a heading close with its own run of hashes; trimming both ends covers it.
        let text = line.dropFirst(hashes.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        return .heading(level: hashes.count, text: text)
    }

    private static func bullet(in line: String) -> String? {
        guard let marker = line.first, "*-+".contains(marker), line.dropFirst().first == " " else { return nil }
        return line.dropFirst().trimmingCharacters(in: .whitespaces)
    }
}

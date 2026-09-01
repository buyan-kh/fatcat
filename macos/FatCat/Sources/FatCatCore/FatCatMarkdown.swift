import Foundation

public enum FatCatMarkdownBlock: Equatable, Sendable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case code(language: String?, text: String)
    case unorderedList([String])
    case orderedList([String])
    case blockquote(String)
    case table(headers: [String], rows: [[String]])
}

public enum FatCatMarkdownParser {
    public static func parse(_ markdown: String) -> [FatCatMarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [FatCatMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { index += 1; continue }

            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var code: [String] = []
                while index < lines.count && !lines[index].hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(language: language.isEmpty ? nil : language, text: code.joined(separator: "\n")))
                continue
            }

            let headingPrefix = line.prefix { $0 == "#" }
            if !headingPrefix.isEmpty && headingPrefix.count <= 6 && line.dropFirst(headingPrefix.count).first == " " {
                blocks.append(.heading(level: headingPrefix.count, text: String(line.dropFirst(headingPrefix.count + 1))))
                index += 1
                continue
            }

            if line.hasPrefix("> ") || line == ">" {
                var quote: [String] = []
                while index < lines.count && (lines[index].hasPrefix("> ") || lines[index] == ">") {
                    quote.append(String(lines[index].dropFirst(min(2, lines[index].count))))
                    index += 1
                }
                blocks.append(.blockquote(quote.joined(separator: "\n")))
                continue
            }

            if index + 1 < lines.count, line.contains("|"), isTableSeparator(index: index + 1, lines: lines) {
                let headers = splitTableRow(line)
                index += 2
                var rows: [[String]] = []
                while index < lines.count && lines[index].contains("|") && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(splitTableRow(lines[index]))
                    index += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            if isTableSeparator(index: index, lines: lines) {
                let headers = splitTableRow(lines[index - 1])
                index += 1
                var rows: [[String]] = []
                while index < lines.count && lines[index].contains("|") && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(splitTableRow(lines[index]))
                    index += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            if isUnordered(line) {
                var items: [String] = []
                while index < lines.count && isUnordered(lines[index]) {
                    items.append(String(lines[index].dropFirst(2)))
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            if isOrdered(line) {
                var items: [String] = []
                while index < lines.count && isOrdered(lines[index]) {
                    guard let dot = lines[index].firstIndex(of: ".") else { break }
                    items.append(String(lines[index][lines[index].index(after: dot)...]).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            var paragraph = [line]
            index += 1
            while index < lines.count,
                  !lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
                  !lines[index].hasPrefix("#"),
                  !lines[index].hasPrefix("```") {
                if isUnordered(lines[index]) || isOrdered(lines[index]) || lines[index].hasPrefix(">") { break }
                paragraph.append(lines[index])
                index += 1
            }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
        }
        return blocks
    }

    private static func isUnordered(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func isOrdered(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: "."), dot > line.startIndex else { return false }
        let afterDot = line.index(after: dot)
        guard afterDot < line.endIndex else { return false }
        return line[..<dot].allSatisfy { $0.isNumber } && line[afterDot] == " "
    }

    private static func isTableSeparator(index: Int, lines: [String]) -> Bool {
        guard index > 0, lines[index].contains("|") else { return false }
        let cells = splitTableRow(lines[index])
        return !cells.isEmpty && cells.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespaces)
            return value.count >= 3 && value.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

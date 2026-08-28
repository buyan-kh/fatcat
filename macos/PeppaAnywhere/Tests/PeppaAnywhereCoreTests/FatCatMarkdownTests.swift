import Testing
@testable import PeppaAnywhereCore

struct FatCatMarkdownTests {
    @Test func parsesCommonNativeMarkdownBlocks() {
        let blocks = FatCatMarkdownParser.parse("""
        # Heading

        A **bold** paragraph with `code`.

        - One
        - Two

        ```swift
        let answer = 42
        ```
        """)

        #expect(blocks.contains(.heading(level: 1, text: "Heading")))
        #expect(blocks.contains(.unorderedList(["One", "Two"])))
        #expect(blocks.contains(.code(language: "swift", text: "let answer = 42")))
    }

    @Test func parsesTablesAndOrderedListsWithoutWebRendering() {
        let blocks = FatCatMarkdownParser.parse("""
        | Name | State |
        | --- | --- |
        | FatCat | ready |

        1. First
        2. Second
        """)

        #expect(blocks.contains(.table(headers: ["Name", "State"], rows: [["FatCat", "ready"]])))
        #expect(blocks.contains(.orderedList(["First", "Second"])))
    }
}

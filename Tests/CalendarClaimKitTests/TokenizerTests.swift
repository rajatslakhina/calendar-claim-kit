@testable import CalendarClaimKit
import XCTest

final class TokenizerTests: XCTestCase {
    func kinds(_ text: String) -> [String] {
        Tokenizer.tokens(text).map { "\($0.kind):\($0.text)" }
    }

    func testWordsNumbersAndMarks() {
        XCTAssertEqual(kinds("It\u{2019}s twenty-one, well- 17th!"), [
            "word:It's", "word:twenty-one", "mark:,", "word:well", "mark:-", "number:17th", "boundary:!"
        ])
        XCTAssertEqual(kinds("Ends.\nNext"), ["word:Ends", "boundary:.", "boundary:\n", "word:Next"])
        XCTAssertEqual(kinds("6.5 weeks; 59."), ["word:6.5", "word:weeks", "boundary:;", "number:59", "boundary:."])
    }

    func testISODates() {
        XCTAssertEqual(kinds("2026-03-17T10:00"), ["iso:2026-03-17", "word:T", "number:10", "mark::", "number:00"])
        XCTAssertEqual(kinds("2026-3-7"), ["iso:2026-3-7"])
        XCTAssertEqual(kinds("2026-03"), ["number:2026", "mark:-", "number:03"])
        XCTAssertEqual(kinds("2026-123-1"), ["number:2026", "mark:-", "number:123", "mark:-", "number:1"])
        XCTAssertEqual(kinds("202-03-17"), ["number:202", "mark:-", "number:03", "mark:-", "number:17"])
    }

    func testLexicon() {
        XCTAssertEqual(Lexicon.numberWord("twenty-one"), 21)
        XCTAssertEqual(Lexicon.numberWord("seven"), 7)
        XCTAssertNil(Lexicon.numberWord("twenty-ten"))
        XCTAssertNil(Lexicon.numberWord("one-two"))
        XCTAssertNil(Lexicon.numberWord("well-known"))
        XCTAssertEqual(Lexicon.suffixedNumber("3rd"), 3)
        XCTAssertNil(Lexicon.suffixedNumber("17x"))
        XCTAssertNil(Lexicon.suffixedNumber("th"))
        XCTAssertNil(Lexicon.plainNumber("1234567"))
        XCTAssertNil(Lexicon.year("0999"))
        XCTAssertEqual(Lexicon.year("2026"), 2026)
    }
}

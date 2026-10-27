@testable import CalendarClaimKit
import XCTest

final class ReaderTests: XCTestCase {
    func testDateForms() {
        let forms: [(String, DateMention)] = [
            ("March 17, 2026", mention(3, 17, 2026)),
            ("17 March 2026", mention(3, 17, 2026)),
            ("the 17th of March", mention(3, 17, nil)),
            ("Mar. 17", mention(3, 17, nil)),
            ("Sept 3 2026", mention(9, 3, 2026)),
            ("2026-03-17", mention(3, 17, 2026)),
            ("May 5", mention(5, 5, nil))
        ]
        for (text, expected) in forms {
            XCTAssertTrue(pieces(text).contains(.date(expected)), text)
        }
        XCTAssertEqual(pieces("Tue, 17 Mar 2026"), [.date(DateMention(month: 3, day: 17, year: 2026, statedWeekday: .tuesday))])
        XCTAssertEqual(pieces("you may 5"), [.word("you"), .word("may"), .number(5)])
        XCTAssertEqual(pieces("2026-13-01"), [.word("2026-13-01")])
        XCTAssertEqual(pieces("Sun, the weekend"), [.word("sun"), .mark(","), .word("the"), .word("weekend")])
    }

    func testOtherPieces() {
        XCTAssertEqual(pieces("the third Tuesday of March 2026"), [
            .word("the"), .ordinal(3), .weekday(.tuesday), .word("of"), .month(MonthMention(month: 3, year: 2026))
        ])
        XCTAssertEqual(pieces("3rd Monday in Mar 2026").prefix(2), [.ordinal(3), .weekday(.monday)])
        XCTAssertEqual(pieces("last Friday of October").first, .ordinal(-1))
        XCTAssertEqual(pieces("last Friday was"), [.word("last"), .weekday(.friday), .word("was")])
        XCTAssertEqual(pieces("6th Monday of"), [.dayOfMonth(6), .weekday(.monday), .word("of")])
        var carried = MonthMention(month: 3, year: 2026)
        carried.yearSource = .text
        XCTAssertEqual(pieces("Mar 2026, Mar, March"), [
            .month(MonthMention(month: 3, year: 2026)), .mark(","), .word("mar"), .mark(","), .month(carried)
        ])
        XCTAssertEqual(pieces("2000 days in 2026"), [.number(2000), .unit(.day), .word("in"), .year(2026)])
        XCTAssertEqual(pieces("a week, an idea, 5 business days, working day, 3 weekdays"), [
            .number(1), .unit(.week), .mark(","), .word("an"), .word("idea"), .mark(","), .number(5), .unit(.businessDay),
            .mark(","), .unit(.businessDay), .mark(","), .number(3), .unit(.businessDay)
        ])
        XCTAssertEqual(pieces("twenty-one tomorrow's 17x 32nd 1234567 business trip"), [
            .number(21), .anchor(.tomorrow), .word("17x"), .word("32nd"), .word("1234567"), .word("business"), .word("trip")
        ])
    }

    func testYearsComeFromTheNearestStatement() {
        func years(_ reading: TextReading) -> [String] {
            reading.pieces.compactMap { piece in
                switch piece {
                case .date(let mention): "\(mention.year.map(String.init) ?? "-") \(mention.yearSource.rawValue)"
                case .month(let mention): "\(mention.year.map(String.init) ?? "-") \(mention.yearSource.rawValue)"
                default: nil
                }
            }
        }
        XCTAssertEqual(years(read("In 2027, March 17 and April 2.")), ["2027 from the text", "2027 from the text"])
        XCTAssertEqual(years(read("Between March 1 and April 1, 2026")), ["2026 from the text", "2026 stated"])
        XCTAssertEqual(years(read("Between December 20 and January 5, 2027")), ["2026 from the text", "2027 stated"])
        XCTAssertEqual(years(read("Between March 1 and 2026")), ["2026 from the text"])
        XCTAssertEqual(years(read("It was 2025. Then March 3.")), ["2025 from the text"])
        XCTAssertEqual(years(read("March 3 in March", context: 2027)), ["2027 from the conversation", "2027 from the conversation"])
        let guessed = read("March 3. Nothing here.", today: 2026)
        XCTAssertEqual(years(guessed), ["2026 from today's date"])
        XCTAssertEqual(guessed.clauses.map(\.guessedYear), [true, false])
        XCTAssertEqual(years(read("March 3")), ["- missing"])
        XCTAssertEqual(read("June 1, 2026; 2027").statedYears, [2026, 2027])
        XCTAssertEqual(read("  ").clauses, [])
        XCTAssertEqual(read("One. Two").clauses.map(\.quote), ["One.", "Two"])
    }

    func testMentions() {
        var february29 = mention(2, 29, 2027)
        XCTAssertTrue(february29.isImpossible)
        february29.yearSource = .today
        XCTAssertFalse(february29.isImpossible)
        XCTAssertTrue(mention(2, 30, nil).isImpossible)
        XCTAssertFalse(mention(2, 29, nil).isImpossible)
        XCTAssertEqual(mention(3, 17, nil).description, "March 17")
        XCTAssertNil(mention(3, 17, nil).civil)
        XCTAssertEqual(MonthMention(month: 2, year: nil).description, "February")
        XCTAssertEqual(CalendarUnit.businessDay.phrase(1), "1 business day")
        XCTAssertEqual(CalendarUnit.week.phrase(-2), "-2 weeks")
        XCTAssertEqual(DateBase.anchor(.yesterday).description, "yesterday")
        XCTAssertEqual(CalendarValue.truth(false).description, "no")
        XCTAssertEqual(CalendarValue.count(3, .under).description, "under 3")
        XCTAssertEqual([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 111].map(CalendarValue.suffix),
                       ["st", "nd", "rd", "th", "th", "th", "th", "st", "nd", "rd", "th"])
        XCTAssertNil(Piece.boundary.word)
        XCTAssertNil(Piece.date(mention(3, 3, nil)).statedYear)
    }
}

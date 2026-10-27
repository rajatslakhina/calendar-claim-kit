@testable import CalendarClaimKit
import XCTest

final class ClauseViewTests: XCTestCase {
    func testQualifiersAndAmounts() {
        XCTAssertEqual(view("less than 5").qualifier(before: 2), .under)
        XCTAssertEqual(view("fewer than 5").qualifier(before: 2), .under)
        XCTAssertEqual(view("more than 5").qualifier(before: 2), .over)
        XCTAssertEqual(view("rather than 5").qualifier(before: 2), .exact)
        XCTAssertEqual(view("roughly 5").qualifier(before: 1), .approximately)
        XCTAssertEqual(view("5").qualifier(before: 0), .exact)
        XCTAssertNil(view("a 90-day trial").amount(at: 0))
        XCTAssertEqual(view("a 90-day trial").amount(at: 1), Amount(amount: 90, unit: .day, next: 4))
        XCTAssertNil(view("It costs 5 dollars").amount(at: 2))
    }

    func testExpressionKinds() {
        let march3 = DateBase.date(mention(3, 3, 2026))
        let kinds: [CalendarExpression] = [
            .weekdayOf(mention(3, 3, 2026)), .offset(base: march3, amount: 1, unit: .day),
            .span(from: march3, to: march3, unit: .day, inclusive: false),
            .nthWeekday(ordinal: 1, weekday: .monday, month: MonthMention(month: 3, year: 2026)),
            .leapYear(2026), .yearLength(2026), .monthLength(MonthMention(month: 3, year: 2026)),
            .anchor(.today), .relative(.next, .friday)
        ]
        XCTAssertEqual(kinds.map(\.kind), [.weekdayOf, .offset, .span, .nthWeekday, .leapYear, .length, .length, .relative, .relative])
    }

    func testRelativeAndMonthOffsetsAgainstTheClock() {
        XCTAssertEqual(statuses(check("Tomorrow is a Wednesday.")), [.verified])
        XCTAssertEqual(statuses(check("Next Friday is October 30.")), [.verified])
        XCTAssertEqual(statuses(check("1 month after January 31, 2026 is February 28, 2026.")), [.verified])
        XCTAssertEqual(statuses(check("It ended March 17, 2026. It started 2 weeks earlier on March 3.")), [.verified])
        XCTAssertEqual(statuses(check("It costs 5 dollars.")), [])
    }
}

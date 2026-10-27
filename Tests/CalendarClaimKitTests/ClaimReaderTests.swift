@testable import CalendarClaimKit
import XCTest

final class ClaimReaderTests: XCTestCase {
    func statements(_ text: String, today: Int? = 2026) -> [String] {
        claims(text, today: today).map { Describe.statement($0) }
    }

    func testWeekdayForms() {
        XCTAssertEqual(statements("Tuesday, March 17, 2026"), ["March 17, 2026 is a Tuesday"])
        XCTAssertEqual(statements("March 17, 2026 is a Monday."), ["March 17, 2026 is a Monday"])
        XCTAssertEqual(statements("March 17, 2026 (Tuesday)"), ["March 17, 2026 is a Tuesday"])
        XCTAssertEqual(statements("June 2, 2026, a Tuesday"), ["June 2, 2026 is a Tuesday"])
        XCTAssertEqual(statements("March 17, 2026, which is not a Monday"), ["March 17, 2026 is not a Monday"])
        XCTAssertEqual(statements("March 17, 2026 isn't a Monday"), ["March 17, 2026 is not a Monday"])
        XCTAssertEqual(statements("March 17, 2026 won't be a Monday"), ["March 17, 2026 is not a Monday"])
        XCTAssertEqual(statements("March 17, 2026 will be a Tuesday"), ["March 17, 2026 is a Tuesday"])
        XCTAssertEqual(statements("after March 17, 2026 is a Tuesday"), [])
        XCTAssertEqual(statements("April 31, 2025 is a Thursday"), [])
        XCTAssertEqual(statements("March 17, 2026 will see"), [])
        XCTAssertEqual(statements("March 17, 2026 is busy"), [])
        XCTAssertEqual(statements("Tuesday, March 17, 2026, Tuesday"), ["March 17, 2026 is a Tuesday"])
    }

    func testOffsetForms() {
        XCTAssertEqual(statements("90 days after March 3, 2026 is June 1, 2026"), ["90 days after March 3, 2026 is June 1, 2026"])
        XCTAssertEqual(statements("June 1, 2026 is exactly 90 days after March 3, 2026"), ["90 days after March 3, 2026 is June 1, 2026"])
        XCTAssertEqual(statements("3 weeks from today, it's a Tuesday"), ["3 weeks after today is a Tuesday"])
        XCTAssertEqual(statements("5 business days before June 1, 2026 is May 25"), ["5 business days before June 1, 2026 is May 25, 2026"])
        XCTAssertEqual(statements("3 days ago was Saturday"), ["3 days before today is a Saturday"])
        XCTAssertEqual(statements("In 10 days it will be the 6th"), ["10 days after today is the 6th"])
        XCTAssertEqual(statements("March 3, 2026 + 90 days = June 1, 2026"), ["90 days after March 3, 2026 is June 1, 2026"])
        XCTAssertEqual(statements("March 3, 2026 minus 2 days is March 1"), ["2 days before March 3, 2026 is March 1, 2026"])
        XCTAssertEqual(statements("June 1, 2026 - 1 month = May 1"), ["1 month before June 1, 2026 is May 1, 2026"])
        XCTAssertEqual(statements("The day before tomorrow is today"), [])
        XCTAssertEqual(statements("The day after tomorrow is Thursday"), ["1 day after tomorrow is a Thursday"])
        XCTAssertEqual(statements("It started March 3, 2026 and ends 2 weeks later on March 17"), [
            "2 weeks after March 3, 2026 is March 17, 2026"
        ])
        XCTAssertEqual(statements("A year earlier than now was 2025"), [])
        XCTAssertEqual(statements("3 days earlier, on March 1"), [])
        XCTAssertEqual(statements("2 days prior to March 3, 2026 is March 1; 1 day later than March 3, 2026 is March 4"), [
            "2 days before March 3, 2026 is March 1, 2026", "1 day after March 3, 2026 is March 4, 2026"
        ])
        XCTAssertEqual(statements("10 days past now is the 6th; 2 days following March 3, 2026 is March 5"), [
            "10 days after today is the 6th", "2 days after March 3, 2026 is March 5, 2026"
        ])
        XCTAssertEqual(statements("5 days after the launch"), [])
        XCTAssertEqual(statements("2 days ahead"), [])
    }

    func testSpanForms() {
        XCTAssertEqual(statements("There are 90 days, or about 13 weeks, between March 3 and June 1, 2026."), [
            "March 3, 2026 to June 1, 2026 is 90 days", "March 3, 2026 to June 1, 2026 is about 13 weeks"
        ])
        XCTAssertEqual(statements("From March 3 through June 1, 2026 is 91 days"), [
            "March 3, 2026 to June 1, 2026 is 91 days, counting both ends"
        ])
        XCTAssertEqual(statements("From March 3 to June 1, 2026 is 91 days, counting both"), [
            "March 3, 2026 to June 1, 2026 is 91 days, counting both ends"
        ])
        XCTAssertEqual(statements("It has been more than 300 days since January 1, 2026"), [
            "January 1, 2026 to today is over 300 days"
        ])
        XCTAssertEqual(statements("Only 59 days until December 25, inclusive"), [
            "today to December 25, 2026 is 59 days, counting both ends"
        ])
        XCTAssertEqual(statements("between March 3 and soon there are 3 days"), [])
        XCTAssertEqual(statements("between March 3 or June 1 there are 3 days"), [])
        XCTAssertEqual(statements("from March 3 onward there are 3 days"), [])
        XCTAssertEqual(statements("from March 3 to soon there are 3 days"), [])
        XCTAssertEqual(statements("since then"), [])
        XCTAssertEqual(statements("until December 25 there is time"), [])
    }

    func testNthYearAndRelativeForms() {
        XCTAssertEqual(statements("The third Tuesday of March 2026 is March 16."), [
            "the third Tuesday of March 2026 is March 16, 2026"
        ])
        XCTAssertEqual(statements("March 17, 2026 is the third Tuesday of the month."), [
            "the third Tuesday of March 2026 is March 17, 2026"
        ])
        XCTAssertEqual(statements("The last Friday in October falls on the 30th."), [
            "the last Friday of October 2026 is the 30th"
        ])
        XCTAssertEqual(statements("The second Monday of the month is the 9th."), [])
        XCTAssertEqual(statements("The second Monday of the year is the 9th."), [])
        XCTAssertEqual(statements("The first Monday in March 2026 is busy."), [])
        XCTAssertEqual(statements("2100 is not a leap year; 2028 will be a leap year; 2027 has 365 days"), [
            "2100 is not a leap year", "2028 is a leap year", "2027 has 365 days"
        ])
        XCTAssertEqual(statements("April has 31 days; February 2028 has 29 days; 2026 is busy; 2026 has 3 weeks"), [
            "April has 31 days", "February 2028 has 29 days"
        ])
        XCTAssertEqual(statements("April is long; April has many days; 2026 was"), [])
        XCTAssertEqual(statements("Today's date is Tuesday, October 27, 2026"), [
            "today is October 27, 2026", "October 27, 2026 is a Tuesday"
        ])
        XCTAssertEqual(statements("Tomorrow, October 28."), ["tomorrow is October 28, 2026"])
        XCTAssertEqual(statements("Yesterday was not a Monday"), ["yesterday is not a Monday"])
        XCTAssertEqual(statements("Tomorrow will be fine; from today we go"), [])
        XCTAssertEqual(statements("Next Friday is October 30; this Friday is the 30th; last Friday was October 23"), [
            "next Friday is October 30, 2026", "this Friday is the 30th", "last Friday is October 23, 2026"
        ])
        XCTAssertEqual(statements("next week is busy; next Friday is busy; next Friday"), [])
    }

    func testClaimsCarryTheirSentenceAndGuess() {
        let found = claims("We met. March 17 is a Tuesday. March 17 is a Tuesday.")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.quote, "March 17 is a Tuesday.")
        XCTAssertEqual(found.first?.guessedYear, true)
        XCTAssertEqual(found.first?.origin, .answer)
    }
}
